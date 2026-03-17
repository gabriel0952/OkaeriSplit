-- Fix delete_user_account to remove all rows that reference profiles(id)
-- before deleting the profile, avoiding FK constraint violations.
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Remove expense_splits where this user is a participant in other users' expenses
  delete from public.expense_splits where user_id = _uid;

  -- Remove expenses paid by this user (cascades to their expense_splits)
  delete from public.expenses where paid_by = _uid;

  -- Remove settlements involving this user
  delete from public.settlements where from_user = _uid or to_user = _uid;

  -- Remove group memberships
  delete from public.group_members where user_id = _uid;

  -- Remove profile
  delete from public.profiles where id = _uid;

  -- Delete auth user
  delete from auth.users where id = _uid;
end;
$$;
