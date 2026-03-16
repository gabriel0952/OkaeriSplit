-- ============================================================
-- share_links table, RPC, and RLS policies
-- ============================================================

-- 1. Table
CREATE TABLE IF NOT EXISTS public.share_links (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  token       TEXT        UNIQUE NOT NULL,
  group_id    UUID        NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  created_by  UUID        NOT NULL REFERENCES public.profiles(id),
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. RPC: create_share_link
CREATE OR REPLACE FUNCTION public.create_share_link(p_group_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token TEXT;
  v_uid   UUID;
BEGIN
  v_uid := auth.uid();

  -- Verify caller is authenticated and is a member of the group
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id
      AND user_id  = v_uid
  ) THEN
    RAISE EXCEPTION 'Forbidden: not a member of this group';
  END IF;

  -- Generate 128-bit random token
  v_token := encode(extensions.gen_random_bytes(16), 'hex');

  INSERT INTO public.share_links (token, group_id, created_by, expires_at)
  VALUES (v_token, p_group_id, v_uid, now() + INTERVAL '3 months');

  RETURN v_token;
END;
$$;

-- 3. RLS: enable on share_links (authenticated users manage their own)
ALTER TABLE public.share_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anon can validate share token"
  ON public.share_links
  FOR SELECT
  TO anon
  USING (
    token = current_setting('request.headers', true)::json->>'x-share-token'
  );

CREATE POLICY "Members can create share links"
  ON public.share_links
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_id = share_links.group_id
        AND user_id  = auth.uid()
    )
  );

-- Helper: check if a token is valid (exists + not expired)
-- Used by anon RLS policies below
CREATE OR REPLACE FUNCTION public.is_valid_share_token(p_token TEXT, p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.share_links
    WHERE token    = p_token
      AND group_id = p_group_id
      AND expires_at > now()
  );
$$;

-- 4. RLS: allow anon to read groups via valid token
-- anon reads query using a custom header or request param;
-- we expose the token as a Postgres setting via the API (set via PostgREST request.jwt.claims or custom header).
-- Approach: anon policy checks share_links table directly for a matching token passed as app.share_token setting.

CREATE POLICY "Anon can read group via valid share token"
  ON public.groups
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_links
      WHERE share_links.group_id  = groups.id
        AND share_links.token     = current_setting('request.headers', true)::json->>'x-share-token'
        AND share_links.expires_at > now()
    )
  );

-- 5. RLS: allow anon to read group_members via valid token
CREATE POLICY "Anon can read group_members via valid share token"
  ON public.group_members
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_links
      WHERE share_links.group_id  = group_members.group_id
        AND share_links.token     = current_setting('request.headers', true)::json->>'x-share-token'
        AND share_links.expires_at > now()
    )
  );

-- 6. RLS: allow anon to read profiles via valid token
-- Only profiles that are members of groups accessible via valid token
CREATE POLICY "Anon can read profiles via valid share token"
  ON public.profiles
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM   public.group_members gm
      JOIN   public.share_links   sl ON sl.group_id = gm.group_id
      WHERE  gm.user_id          = profiles.id
        AND  sl.token            = current_setting('request.headers', true)::json->>'x-share-token'
        AND  sl.expires_at       > now()
    )
  );

-- 7. RLS: allow anon to read expenses via valid token
CREATE POLICY "Anon can read expenses via valid share token"
  ON public.expenses
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_links
      WHERE share_links.group_id  = expenses.group_id
        AND share_links.token     = current_setting('request.headers', true)::json->>'x-share-token'
        AND share_links.expires_at > now()
    )
  );

-- 8. RLS: allow anon to read expense_splits via valid token
CREATE POLICY "Anon can read expense_splits via valid share token"
  ON public.expense_splits
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM   public.expenses e
      JOIN   public.share_links sl ON sl.group_id = e.group_id
      WHERE  e.id          = expense_splits.expense_id
        AND  sl.token      = current_setting('request.headers', true)::json->>'x-share-token'
        AND  sl.expires_at > now()
    )
  );
