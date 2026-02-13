-- ============================================================
-- OkaeriSplit — Initial Schema Migration
-- ============================================================

-- 2.1 profiles
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_url  TEXT,
  email       TEXT NOT NULL,
  default_currency TEXT NOT NULL DEFAULT 'TWD',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-create profile on auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 2.2 groups
CREATE TABLE groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('roommate', 'travel', 'event')),
  currency    TEXT NOT NULL DEFAULT 'TWD',
  invite_code TEXT UNIQUE NOT NULL DEFAULT substr(md5(random()::text), 1, 6),
  created_by  UUID NOT NULL REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_groups_invite_code ON groups(invite_code);

-- 2.3 group_members
CREATE TABLE group_members (
  group_id  UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

-- 2.4 expenses
CREATE TYPE expense_category AS ENUM (
  'food', 'transport', 'accommodation',
  'entertainment', 'daily_necessities', 'other'
);

CREATE TABLE expenses (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  paid_by      UUID NOT NULL REFERENCES profiles(id),
  amount       NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  currency     TEXT NOT NULL DEFAULT 'TWD',
  category     expense_category NOT NULL DEFAULT 'other',
  description  TEXT NOT NULL,
  note         TEXT,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_expenses_group_id ON expenses(group_id);
CREATE INDEX idx_expenses_paid_by ON expenses(paid_by);

-- 2.5 expense_splits
CREATE TABLE expense_splits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id),
  amount     NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  split_type TEXT NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'custom_ratio', 'fixed_amount')),
  UNIQUE (expense_id, user_id)
);

CREATE INDEX idx_expense_splits_expense_id ON expense_splits(expense_id);

-- 2.6 settlements
CREATE TABLE settlements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  from_user  UUID NOT NULL REFERENCES profiles(id),
  to_user    UUID NOT NULL REFERENCES profiles(id),
  amount     NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  currency   TEXT NOT NULL DEFAULT 'TWD',
  settled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (from_user <> to_user)
);

CREATE INDEX idx_settlements_group_id ON settlements(group_id);

-- 2.7 updated_at auto-update trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS Policies
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

-- Helper: check group membership
CREATE OR REPLACE FUNCTION is_group_member(gid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = gid AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- profiles
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE TO authenticated USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- groups
CREATE POLICY "groups_select" ON groups
  FOR SELECT TO authenticated USING (is_group_member(id));

CREATE POLICY "groups_insert" ON groups
  FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());

CREATE POLICY "groups_update" ON groups
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = id AND user_id = auth.uid() AND role = 'owner'
    )
  );

-- group_members
CREATE POLICY "group_members_select" ON group_members
  FOR SELECT TO authenticated USING (is_group_member(group_id));

CREATE POLICY "group_members_insert" ON group_members
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "group_members_delete" ON group_members
  FOR DELETE TO authenticated USING (
    user_id = auth.uid()
    AND role <> 'owner'
  );

-- expenses
CREATE POLICY "expenses_select" ON expenses
  FOR SELECT TO authenticated USING (is_group_member(group_id));

CREATE POLICY "expenses_insert" ON expenses
  FOR INSERT TO authenticated WITH CHECK (is_group_member(group_id));

CREATE POLICY "expenses_update" ON expenses
  FOR UPDATE TO authenticated USING (paid_by = auth.uid());

CREATE POLICY "expenses_delete" ON expenses
  FOR DELETE TO authenticated USING (paid_by = auth.uid());

-- expense_splits
CREATE POLICY "expense_splits_select" ON expense_splits
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND is_group_member(e.group_id)
    )
  );

CREATE POLICY "expense_splits_insert" ON expense_splits
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND is_group_member(e.group_id)
    )
  );

CREATE POLICY "expense_splits_update" ON expense_splits
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND e.paid_by = auth.uid()
    )
  );

CREATE POLICY "expense_splits_delete" ON expense_splits
  FOR DELETE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND e.paid_by = auth.uid()
    )
  );

-- settlements
CREATE POLICY "settlements_select" ON settlements
  FOR SELECT TO authenticated USING (is_group_member(group_id));

CREATE POLICY "settlements_insert" ON settlements
  FOR INSERT TO authenticated WITH CHECK (
    from_user = auth.uid() AND is_group_member(group_id)
  );

-- ============================================================
-- RPC Functions
-- ============================================================

-- create_group
CREATE OR REPLACE FUNCTION create_group(
  p_name TEXT,
  p_type TEXT,
  p_currency TEXT DEFAULT 'TWD'
)
RETURNS UUID AS $$
DECLARE
  v_group_id UUID;
  v_invite_code TEXT;
  v_retry INT := 0;
BEGIN
  LOOP
    v_invite_code := substr(md5(random()::text), 1, 6);
    BEGIN
      INSERT INTO groups (name, type, currency, invite_code, created_by)
      VALUES (p_name, p_type, p_currency, v_invite_code, auth.uid())
      RETURNING id INTO v_group_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_retry := v_retry + 1;
      IF v_retry > 5 THEN
        RAISE EXCEPTION 'Failed to generate unique invite code';
      END IF;
    END;
  END LOOP;

  INSERT INTO group_members (group_id, user_id, role)
  VALUES (v_group_id, auth.uid(), 'owner');

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- create_expense
CREATE OR REPLACE FUNCTION create_expense(
  p_group_id UUID,
  p_paid_by UUID,
  p_amount NUMERIC,
  p_currency TEXT,
  p_category expense_category,
  p_description TEXT,
  p_note TEXT DEFAULT NULL,
  p_expense_date DATE DEFAULT CURRENT_DATE,
  p_splits JSONB DEFAULT '[]'
)
RETURNS UUID AS $$
DECLARE
  v_expense_id UUID;
  v_split JSONB;
BEGIN
  IF NOT is_group_member(p_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  INSERT INTO expenses (group_id, paid_by, amount, currency, category, description, note, expense_date)
  VALUES (p_group_id, p_paid_by, p_amount, p_currency, p_category, p_description, p_note, p_expense_date)
  RETURNING id INTO v_expense_id;

  FOR v_split IN SELECT * FROM jsonb_array_elements(p_splits)
  LOOP
    INSERT INTO expense_splits (expense_id, user_id, amount, split_type)
    VALUES (
      v_expense_id,
      (v_split->>'user_id')::UUID,
      (v_split->>'amount')::NUMERIC,
      COALESCE(v_split->>'split_type', 'equal')
    );
  END LOOP;

  RETURN v_expense_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_user_balances
CREATE OR REPLACE FUNCTION get_user_balances(p_group_id UUID)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  total_paid NUMERIC,
  total_owed NUMERIC,
  net_balance NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH paid AS (
    SELECT e.paid_by AS uid, COALESCE(SUM(e.amount), 0) AS total
    FROM expenses e
    WHERE e.group_id = p_group_id
    GROUP BY e.paid_by
  ),
  owed AS (
    SELECT es.user_id AS uid, COALESCE(SUM(es.amount), 0) AS total
    FROM expense_splits es
    JOIN expenses e ON e.id = es.expense_id
    WHERE e.group_id = p_group_id
    GROUP BY es.user_id
  ),
  settled_out AS (
    SELECT s.from_user AS uid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.group_id = p_group_id
    GROUP BY s.from_user
  ),
  settled_in AS (
    SELECT s.to_user AS uid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.group_id = p_group_id
    GROUP BY s.to_user
  )
  SELECT
    gm.user_id,
    p.display_name,
    p.avatar_url,
    COALESCE(pd.total, 0) AS total_paid,
    COALESCE(ow.total, 0) AS total_owed,
    COALESCE(pd.total, 0) - COALESCE(ow.total, 0)
      + COALESCE(so.total, 0) - COALESCE(si.total, 0) AS net_balance
  FROM group_members gm
  JOIN profiles p ON p.id = gm.user_id
  LEFT JOIN paid pd ON pd.uid = gm.user_id
  LEFT JOIN owed ow ON ow.uid = gm.user_id
  LEFT JOIN settled_out so ON so.uid = gm.user_id
  LEFT JOIN settled_in si ON si.uid = gm.user_id
  WHERE gm.group_id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- get_overall_balances
CREATE OR REPLACE FUNCTION get_overall_balances(p_user_id UUID)
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  net_balance NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH paid AS (
    SELECT e.group_id AS gid, COALESCE(SUM(e.amount), 0) AS total
    FROM expenses e
    WHERE e.paid_by = p_user_id
    GROUP BY e.group_id
  ),
  owed AS (
    SELECT e.group_id AS gid, COALESCE(SUM(es.amount), 0) AS total
    FROM expense_splits es
    JOIN expenses e ON e.id = es.expense_id
    WHERE es.user_id = p_user_id
    GROUP BY e.group_id
  ),
  settled_out AS (
    SELECT s.group_id AS gid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.from_user = p_user_id
    GROUP BY s.group_id
  ),
  settled_in AS (
    SELECT s.group_id AS gid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.to_user = p_user_id
    GROUP BY s.group_id
  )
  SELECT
    g.id,
    g.name,
    COALESCE(pd.total, 0) - COALESCE(ow.total, 0)
      + COALESCE(so.total, 0) - COALESCE(si.total, 0) AS net_balance
  FROM group_members gm
  JOIN groups g ON g.id = gm.group_id
  LEFT JOIN paid pd ON pd.gid = g.id
  LEFT JOIN owed ow ON ow.gid = g.id
  LEFT JOIN settled_out so ON so.gid = g.id
  LEFT JOIN settled_in si ON si.gid = g.id
  WHERE gm.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- join_group_by_code
CREATE OR REPLACE FUNCTION join_group_by_code(p_invite_code TEXT)
RETURNS UUID AS $$
DECLARE
  v_group_id UUID;
BEGIN
  SELECT id INTO v_group_id
  FROM groups
  WHERE invite_code = p_invite_code;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  INSERT INTO group_members (group_id, user_id, role)
  VALUES (v_group_id, auth.uid(), 'member')
  ON CONFLICT (group_id, user_id) DO NOTHING;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
