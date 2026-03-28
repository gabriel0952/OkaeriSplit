-- Allow either participant in a settlement to record the payment.
-- The suggested-transfer UI intentionally exposes the action to both sides,
-- so RLS must accept inserts from either the payer or the payee.

DROP POLICY IF EXISTS "settlements_insert" ON settlements;
CREATE POLICY "settlements_insert" ON settlements
  FOR INSERT TO authenticated
  WITH CHECK (
    (from_user = auth.uid() OR to_user = auth.uid())
    AND is_group_member(group_id)
    AND NOT is_guest_user()
    AND (SELECT status FROM groups WHERE id = group_id) = 'active'
  );
