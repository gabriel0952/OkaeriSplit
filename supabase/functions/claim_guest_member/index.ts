import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Simple in-memory rate limit: { ip -> { count, resetAt } }
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 5;
const RATE_WINDOW_MS = 60_000;

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }
  if (entry.count >= RATE_LIMIT) return false;
  entry.count++;
  return true;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const ip = req.headers.get('x-forwarded-for') ?? 'unknown';
  if (!checkRateLimit(ip)) {
    return new Response(JSON.stringify({ error: '請求過於頻繁，請稍後再試' }), {
      status: 429,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { group_invite_code, claim_code } = await req.json();

    if (!group_invite_code || !claim_code) {
      return new Response(JSON.stringify({ error: '缺少必要參數' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Find group by invite code
    const { data: group } = await supabaseAdmin
      .from('groups')
      .select('id')
      .eq('invite_code', group_invite_code.toLowerCase())
      .single();

    if (!group) {
      return new Response(JSON.stringify({ error: '無效的群組代碼' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Find guest profile by claim_code
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('id, email, is_guest')
      .eq('claim_code', claim_code.toUpperCase())
      .eq('is_guest', true)
      .single();

    if (!profile) {
      return new Response(JSON.stringify({ error: '無效的訪客代碼' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Confirm this guest is a member of the group
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('user_id')
      .eq('group_id', group.id)
      .eq('user_id', profile.id)
      .single();

    if (!membership) {
      return new Response(JSON.stringify({ error: '訪客代碼與群組代碼不符' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Generate magic link and return the hashed token for client-side verifyOTP
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: profile.email,
    });

    if (linkError || !linkData?.properties?.hashed_token) {
      console.error('generateLink error:', linkError);
      return new Response(JSON.stringify({ error: '產生登入憑證失敗' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Invalidate claim_code so it cannot be reused to generate another magic link.
    await supabaseAdmin
      .from('profiles')
      .update({ claim_code: null })
      .eq('id', profile.id);

    return new Response(
      JSON.stringify({
        hashed_token: linkData.properties.hashed_token,
        group_id: group.id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('unexpected error:', err);
    return new Response(JSON.stringify({ error: '伺服器錯誤' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
