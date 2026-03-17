-- Allow anon to read settlements via valid share token
-- Required for web share page to show accurate current balances (after settlements)

CREATE POLICY "Anon can read settlements via valid share token"
  ON public.settlements
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_links
      WHERE share_links.group_id  = settlements.group_id
        AND share_links.token     = current_setting('request.headers', true)::json->>'x-share-token'
        AND share_links.expires_at > now()
    )
  );
