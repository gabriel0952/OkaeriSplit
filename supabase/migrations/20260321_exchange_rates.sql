-- ─── group_exchange_rates table ───────────────────────────────────────────────

CREATE TABLE group_exchange_rates (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  currency   TEXT NOT NULL,
  rate       NUMERIC(18,6) NOT NULL CHECK (rate > 0),
  updated_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (group_id, currency)
);

ALTER TABLE group_exchange_rates ENABLE ROW LEVEL SECURITY;

-- Group members can read exchange rates.
CREATE POLICY "members can view exchange rates"
  ON group_exchange_rates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_exchange_rates.group_id
        AND gm.user_id = auth.uid()
    )
  );

-- Non-guest members can insert, update, and delete exchange rates.
CREATE POLICY "members can manage exchange rates"
  ON group_exchange_rates FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      JOIN profiles p ON p.id = gm.user_id
      WHERE gm.group_id = group_exchange_rates.group_id
        AND gm.user_id = auth.uid()
        AND p.is_guest = false
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm
      JOIN profiles p ON p.id = gm.user_id
      WHERE gm.group_id = group_exchange_rates.group_id
        AND gm.user_id = auth.uid()
        AND p.is_guest = false
    )
  );

-- ─── Update get_user_balances to apply exchange rate conversion ────────────────

CREATE OR REPLACE FUNCTION get_user_balances(p_group_id UUID)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  total_paid NUMERIC,
  total_owed NUMERIC,
  net_balance NUMERIC
) AS $$
DECLARE
  v_group_currency TEXT;
BEGIN
  SELECT currency INTO v_group_currency FROM groups WHERE id = p_group_id;

  RETURN QUERY
  WITH paid AS (
    SELECT
      e.paid_by AS uid,
      COALESCE(SUM(
        e.amount * CASE
          WHEN e.currency = v_group_currency THEN 1
          ELSE COALESCE(
            (SELECT rate FROM group_exchange_rates ger
             WHERE ger.group_id = p_group_id AND ger.currency = e.currency),
            1
          )
        END
      ), 0) AS total
    FROM expenses e
    WHERE e.group_id = p_group_id
    GROUP BY e.paid_by
  ),
  owed AS (
    SELECT
      es.user_id AS uid,
      COALESCE(SUM(
        es.amount * CASE
          WHEN e.currency = v_group_currency THEN 1
          ELSE COALESCE(
            (SELECT rate FROM group_exchange_rates ger
             WHERE ger.group_id = p_group_id AND ger.currency = e.currency),
            1
          )
        END
      ), 0) AS total
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
