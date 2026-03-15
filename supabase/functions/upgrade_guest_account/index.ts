import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Verify caller is authenticated
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: '未授權' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user: caller }, error: userError } = await supabaseAdmin.auth.getUser(jwt);
    if (userError || !caller) {
      return new Response(JSON.stringify({ error: '未授權' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Only guests can upgrade
    if (!caller.user_metadata?.is_guest) {
      return new Response(JSON.stringify({ error: '此操作僅限訪客帳號' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1.1 Parse body
    const { email, password, display_name } = await req.json();

    // 1.2 Validate inputs
    if (!email || !password || !display_name) {
      return new Response(JSON.stringify({ error: '缺少必要參數' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return new Response(JSON.stringify({ error: '無效的 Email 格式' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if ((password as string).length < 8) {
      return new Response(JSON.stringify({ error: '密碼至少需要 8 個字元' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1.3 Check email conflict via admin updateUser (GoTrue returns error if taken)
    // We attempt the update and inspect the error to detect 409 scenarios.

    // 1.4 Update auth user: email, password, clear is_guest flag
    const { error: updateAuthError } = await supabaseAdmin.auth.admin.updateUserById(
      caller.id,
      {
        email,
        password,
        email_confirm: true,
        user_metadata: { is_guest: false, display_name },
      },
    );

    if (updateAuthError) {
      console.error('updateUserById error:', updateAuthError);
      const msg = updateAuthError.message.toLowerCase();
      // GoTrue returns this message when email is already registered
      if (
        msg.includes('already been registered') ||
        msg.includes('already registered') ||
        msg.includes('already used') ||
        msg.includes('email exists')
      ) {
        return new Response(JSON.stringify({ error: '此 email 已被其他帳號使用' }), {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify({ error: '帳號升級失敗' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1.5 Update profiles table
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .update({ is_guest: false, display_name })
      .eq('id', caller.id);

    if (profileError) {
      console.error('profile update error:', profileError);
      // Auth user updated successfully; profile inconsistency is recoverable on retry
      return new Response(JSON.stringify({ error: '帳號升級部分失敗，請重試' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1.6 Return success
    return new Response(
      JSON.stringify({ success: true }),
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
