-- Allow non-guest members to update groups directly.
-- This matches the current product decision that regular members
-- (not only owners) may edit the group title.

DROP FUNCTION IF EXISTS update_group_name(UUID, TEXT);

DROP POLICY IF EXISTS "groups_update" ON groups;
CREATE POLICY "groups_update" ON groups
  FOR UPDATE TO authenticated
  USING (
    is_group_member(id)
    AND NOT is_guest_user()
  )
  WITH CHECK (
    is_group_member(id)
    AND NOT is_guest_user()
  );
