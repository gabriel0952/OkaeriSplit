-- Restrict profiles visibility to own profile + members of shared groups.
-- Previously USING (true) allowed any authenticated user to enumerate all profiles.
DROP POLICY IF EXISTS "profiles_select" ON profiles;

CREATE POLICY "profiles_select" ON profiles
  FOR SELECT TO authenticated USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members gm1
      JOIN group_members gm2 ON gm2.group_id = gm1.group_id
      WHERE gm1.user_id = auth.uid()
        AND gm2.user_id = profiles.id
    )
  );
