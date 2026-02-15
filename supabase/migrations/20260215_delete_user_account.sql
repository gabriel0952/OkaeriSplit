-- RPC function to delete the current user's account
-- Requires security definer to access auth.users
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

  -- Remove from group_members
  delete from public.group_members where user_id = _uid;

  -- Remove profile
  delete from public.profiles where id = _uid;

  -- Delete auth user
  delete from auth.users where id = _uid;
end;
$$;

-- Only authenticated users can call this
revoke all on function public.delete_user_account() from anon;
grant execute on function public.delete_user_account() to authenticated;
