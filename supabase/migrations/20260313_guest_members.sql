-- ─── 1.1 profiles 新增欄位 ────────────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_guest BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS claim_code TEXT UNIQUE;

CREATE INDEX IF NOT EXISTS idx_profiles_claim_code ON profiles(claim_code)
  WHERE claim_code IS NOT NULL;

-- ─── 1.2 is_guest_user() 輔助函式 ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION is_guest_user()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_guest FROM profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ─── 1.3 RLS 政策：所有寫入加入 AND NOT is_guest_user() ─────────────────────

-- expenses
DROP POLICY IF EXISTS "expenses_insert" ON expenses;
CREATE POLICY "expenses_insert" ON expenses
  FOR INSERT TO authenticated
  WITH CHECK (is_group_member(group_id) AND NOT is_guest_user());

DROP POLICY IF EXISTS "expenses_update" ON expenses;
CREATE POLICY "expenses_update" ON expenses
  FOR UPDATE TO authenticated
  USING (is_group_member(group_id) AND NOT is_guest_user());

DROP POLICY IF EXISTS "expenses_delete" ON expenses;
CREATE POLICY "expenses_delete" ON expenses
  FOR DELETE TO authenticated
  USING (is_group_member(group_id) AND NOT is_guest_user());

-- expense_splits
DROP POLICY IF EXISTS "expense_splits_insert" ON expense_splits;
CREATE POLICY "expense_splits_insert" ON expense_splits
  FOR INSERT TO authenticated
  WITH CHECK (NOT is_guest_user());

DROP POLICY IF EXISTS "expense_splits_update" ON expense_splits;
CREATE POLICY "expense_splits_update" ON expense_splits
  FOR UPDATE TO authenticated
  USING (NOT is_guest_user());

DROP POLICY IF EXISTS "expense_splits_delete" ON expense_splits;
CREATE POLICY "expense_splits_delete" ON expense_splits
  FOR DELETE TO authenticated
  USING (NOT is_guest_user());

-- group_members
DROP POLICY IF EXISTS "group_members_insert" ON group_members;
CREATE POLICY "group_members_insert" ON group_members
  FOR INSERT TO authenticated
  WITH CHECK (NOT is_guest_user());

DROP POLICY IF EXISTS "group_members_delete" ON group_members;
CREATE POLICY "group_members_delete" ON group_members
  FOR DELETE TO authenticated
  USING (NOT is_guest_user());

-- settlements
DROP POLICY IF EXISTS "settlements_insert" ON settlements;
CREATE POLICY "settlements_insert" ON settlements
  FOR INSERT TO authenticated
  WITH CHECK (is_group_member(group_id) AND NOT is_guest_user());
