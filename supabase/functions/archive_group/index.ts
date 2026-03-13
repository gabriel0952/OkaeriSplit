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

    const { group_id } = await req.json();

    if (!group_id) {
      return new Response(JSON.stringify({ error: '缺少必要參數' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Verify caller is owner
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('role')
      .eq('group_id', group_id)
      .eq('user_id', caller.id)
      .single();

    if (!membership || membership.role !== 'owner') {
      return new Response(JSON.stringify({ error: '只有群組管理員可以封存群組' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3.1 Find all guest members in this group
    const { data: guestMembers, error: guestError } = await supabaseAdmin
      .from('group_members')
      .select('user_id, profiles!inner(is_guest)')
      .eq('group_id', group_id)
      .eq('profiles.is_guest', true);

    if (guestError) {
      console.error('guest query error:', guestError);
    }

    // 3.2 Delete each guest auth user (CASCADE removes profiles + group_members)
    if (guestMembers && guestMembers.length > 0) {
      for (const member of guestMembers) {
        const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
          member.user_id,
        );
        if (deleteError) {
          console.error(`deleteUser error for ${member.user_id}:`, deleteError);
          // Non-fatal: continue archiving even if individual delete fails
        }
      }
    }

    // Archive the group
    const { error: archiveError } = await supabaseAdmin
      .from('groups')
      .update({ status: 'archived', updated_at: new Date().toISOString() })
      .eq('id', group_id);

    if (archiveError) {
      console.error('archive error:', archiveError);
      return new Response(JSON.stringify({ error: '封存失敗' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

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
