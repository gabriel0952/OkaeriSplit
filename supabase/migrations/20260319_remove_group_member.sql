-- Remove a group member safely.
-- Rules:
--   1. Caller must be the group owner.
--   2. Target must not be the owner.
--   3. Target must have a net balance of 0 within the group
--      (i.e. all debts settled). If not, the function raises an error
--      so the client can prompt the user to settle first.
--   4. On success: delete the group_members row only.
--      Expense / split history is intentionally preserved for audit purposes.

CREATE OR REPLACE FUNCTION remove_group_member(
  p_group_id UUID,
  p_user_id  UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _caller_id   UUID := auth.uid();
  _caller_role TEXT;
  _target_role TEXT;
  _net         NUMERIC;
BEGIN
  -- 1. Caller must be authenticated
  IF _caller_id IS NULL THEN
    RAISE EXCEPTION '未登入';
  END IF;

  -- 2. Caller must be the group owner
  SELECT role INTO _caller_role
  FROM group_members
  WHERE group_id = p_group_id AND user_id = _caller_id;

  IF _caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION '只有管理員可以移除成員';
  END IF;

  -- 3. Target must exist and must not be an owner
  SELECT role INTO _target_role
  FROM group_members
  WHERE group_id = p_group_id AND user_id = p_user_id;

  IF _target_role IS NULL THEN
    RAISE EXCEPTION '找不到該成員';
  END IF;

  IF _target_role = 'owner' THEN
    RAISE EXCEPTION '無法移除管理員';
  END IF;

  -- 4. Calculate the target member's net balance within this group
  --    net = total_paid - total_owed + settled_received - settled_sent
  SELECT
    COALESCE((
      SELECT SUM(e.amount)
      FROM expenses e
      WHERE e.group_id = p_group_id AND e.paid_by = p_user_id
    ), 0)
    - COALESCE((
      SELECT SUM(es.amount)
      FROM expense_splits es
      JOIN expenses e ON e.id = es.expense_id
      WHERE e.group_id = p_group_id AND es.user_id = p_user_id
    ), 0)
    + COALESCE((
      SELECT SUM(amount)
      FROM settlements
      WHERE group_id = p_group_id AND to_user = p_user_id
    ), 0)
    - COALESCE((
      SELECT SUM(amount)
      FROM settlements
      WHERE group_id = p_group_id AND from_user = p_user_id
    ), 0)
  INTO _net;

  IF ABS(COALESCE(_net, 0)) > 0.01 THEN
    RAISE EXCEPTION '該成員尚有未結清帳款（淨額 %），請先結算後再移除', ROUND(_net, 2);
  END IF;

  -- 5. Safe to remove
  DELETE FROM group_members
  WHERE group_id = p_group_id AND user_id = p_user_id;
END;
$$;
