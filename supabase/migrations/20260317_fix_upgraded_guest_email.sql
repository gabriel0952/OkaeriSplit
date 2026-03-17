-- Fix profiles.email for accounts that were upgraded from guest
-- but still have the guest placeholder email stored in profiles.
UPDATE profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id
  AND p.is_guest = false
  AND p.email LIKE 'guest-%@internal.okaerisplit.app';
