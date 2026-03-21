-- Allow anonymous users to read group_exchange_rates via a valid share token.
-- This mirrors the pattern used for groups, expenses, etc. in 20260317_share_links.sql.

CREATE POLICY "Anon can read exchange rates via valid share token"
  ON public.group_exchange_rates
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_links
      WHERE share_links.group_id  = group_exchange_rates.group_id
        AND share_links.token     = current_setting('request.headers', true)::json->>'x-share-token'
        AND share_links.expires_at > now()
    )
  );
