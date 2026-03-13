-- ─── 1.1 groups 表新增 status 欄位 ───────────────────────────────────────────
ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active', 'archived'));

-- ─── 1.2 RLS 政策：封存群組禁止寫入 ──────────────────────────────────────────

-- expenses
DROP POLICY IF EXISTS "expenses_insert" ON expenses;
CREATE POLICY "expenses_insert" ON expenses
  FOR INSERT TO authenticated
  WITH CHECK (
    is_group_member(group_id)
    AND NOT is_guest_user()
    AND (SELECT status FROM groups WHERE id = group_id) = 'active'
  );

DROP POLICY IF EXISTS "expenses_update" ON expenses;
CREATE POLICY "expenses_update" ON expenses
  FOR UPDATE TO authenticated
  USING (
    is_group_member(group_id)
    AND NOT is_guest_user()
    AND (SELECT status FROM groups WHERE id = group_id) = 'active'
  );

DROP POLICY IF EXISTS "expenses_delete" ON expenses;
CREATE POLICY "expenses_delete" ON expenses
  FOR DELETE TO authenticated
  USING (
    is_group_member(group_id)
    AND NOT is_guest_user()
    AND (SELECT status FROM groups WHERE id = group_id) = 'active'
  );

-- group_members
DROP POLICY IF EXISTS "group_members_insert" ON group_members;
CREATE POLICY "group_members_insert" ON group_members
  FOR INSERT TO authenticated
  WITH CHECK (
    NOT is_guest_user()
    AND (SELECT status FROM groups WHERE id = group_id) = 'active'
  );

-- settlements
DROP POLICY IF EXISTS "settlements_insert" ON settlements;
CREATE POLICY "settlements_insert" ON settlements
  FOR INSERT TO authenticated
  WITH CHECK (
    from_user = auth.uid()
    AND is_group_member(group_id)
    AND NOT is_guest_user()
    AND (SELECT status FROM groups WHERE id = group_id) = 'active'
  );

-- ─── 2.2 reopen_group RPC ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION reopen_group(p_group_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND role = 'owner'
  ) THEN
    RAISE EXCEPTION '只有群組管理員可以重新開啟群組';
  END IF;

  UPDATE groups
    SET status = 'active', updated_at = now()
    WHERE id = p_group_id AND status = 'archived';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── join_group_by_code：封存群組無法加入 ────────────────────────────────────
CREATE OR REPLACE FUNCTION join_group_by_code(p_invite_code TEXT)
RETURNS UUID AS $$
DECLARE
  v_group_id UUID;
  v_status   TEXT;
BEGIN
  SELECT id, status INTO v_group_id, v_status
  FROM groups
  WHERE invite_code = p_invite_code;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  IF v_status = 'archived' THEN
    RAISE EXCEPTION '此群組已結束，無法加入';
  END IF;

  INSERT INTO group_members (group_id, user_id, role)
  VALUES (v_group_id, auth.uid(), 'member')
  ON CONFLICT (group_id, user_id) DO NOTHING;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
