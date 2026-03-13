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
    // Use service role key for admin operations
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

    const { group_id, display_name } = await req.json();

    if (!group_id || !display_name?.trim()) {
      return new Response(JSON.stringify({ error: '缺少必要參數' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Verify caller is a member of the group
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('user_id')
      .eq('group_id', group_id)
      .eq('user_id', caller.id)
      .single();

    if (!membership) {
      return new Response(JSON.stringify({ error: '無權限操作此群組' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Generate 6-char alphanumeric claim code
    const claimCode = Array.from(
      { length: 6 },
      () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Math.floor(Math.random() * 32)],
    ).join('');

    const guestEmail = `guest-${crypto.randomUUID()}@internal.okaerisplit.app`;

    // Create auth user (email confirmed, no password)
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email: guestEmail,
      email_confirm: true,
      user_metadata: { display_name: display_name.trim(), is_guest: true },
    });

    if (createError || !newUser.user) {
      console.error('createUser error:', createError);
      return new Response(JSON.stringify({ error: '建立訪客帳號失敗' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const guestUserId = newUser.user.id;

    // Create profile (upsert in case the auth trigger already created a row)
    const { error: profileError } = await supabaseAdmin.from('profiles').upsert({
      id: guestUserId,
      email: guestEmail,
      display_name: display_name.trim(),
      is_guest: true,
      claim_code: claimCode,
    });

    if (profileError) {
      console.error('profile insert error:', profileError);
      await supabaseAdmin.auth.admin.deleteUser(guestUserId);
      return new Response(JSON.stringify({ error: '建立訪客資料失敗' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Add to group_members
    const { error: memberError } = await supabaseAdmin.from('group_members').insert({
      group_id,
      user_id: guestUserId,
      role: 'member',
    });

    if (memberError) {
      console.error('group_members insert error:', memberError);
      await supabaseAdmin.auth.admin.deleteUser(guestUserId);
      return new Response(JSON.stringify({ error: '加入群組失敗' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({ claim_code: claimCode, user_id: guestUserId }),
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
