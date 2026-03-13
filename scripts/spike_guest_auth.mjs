/**
 * Spike: Guest Member Auth 技術驗證
 *
 * 驗證三個技術問題：
 *   1. admin.generateLink() 可否對同一 user 重複呼叫？
 *   2. verifyOtp({ token_hash }) 不透過 URL，純 token 是否可完成 auth？
 *   3. admin.deleteUser() 後，現有 session 是否立即失效？
 *
 * 使用方式：
 *   SUPABASE_URL=https://xxx.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key \
 *   node scripts/spike_guest_auth.mjs
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('❌ 缺少環境變數：SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

// Admin client（用 service_role key）
const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// 一般 client（用來模擬訪客 APP 端操作）
const client = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const TEST_EMAIL = `spike-guest-${Date.now()}@internal.okaerisplit.app`;

let createdUserId = null;

// ─────────────────────────────────────────────
// 測試 1：建立假 email guest user
// ─────────────────────────────────────────────
async function test1_createGuestUser() {
  console.log('\n── 測試 1：建立 guest user ──');

  const { data, error } = await admin.auth.admin.createUser({
    email: TEST_EMAIL,
    email_confirm: true,  // 跳過 email 驗證
  });

  if (error) {
    console.error('❌ createUser 失敗：', error.message);
    return false;
  }

  createdUserId = data.user.id;
  console.log('✅ 建立成功');
  console.log('   user_id:', createdUserId);
  console.log('   email:', data.user.email);
  return true;
}

// ─────────────────────────────────────────────
// 測試 2：generateLink 第一次呼叫
// ─────────────────────────────────────────────
async function test2_firstGenerateLink() {
  console.log('\n── 測試 2：第一次 generateLink ──');

  const { data, error } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email: TEST_EMAIL,
  });

  if (error) {
    console.error('❌ generateLink 失敗：', error.message);
    return null;
  }

  console.log('✅ 成功');
  console.log('   hashed_token:', data.properties?.hashed_token?.substring(0, 20) + '...');
  return data.properties?.hashed_token;
}

// ─────────────────────────────────────────────
// 測試 3：verifyOtp 用 token_hash 登入（不需要 URL）
// ─────────────────────────────────────────────
async function test3_verifyOtp(hashedToken) {
  console.log('\n── 測試 3：verifyOtp with token_hash ──');

  const { data, error } = await client.auth.verifyOtp({
    token_hash: hashedToken,
    type: 'magiclink',
  });

  if (error) {
    console.error('❌ verifyOtp 失敗：', error.message);
    return null;
  }

  console.log('✅ 登入成功');
  console.log('   user_id:', data.user?.id);
  console.log('   access_token 前 30 碼:', data.session?.access_token?.substring(0, 30) + '...');
  return data.session;
}

// ─────────────────────────────────────────────
// 測試 4：同一 user 重複呼叫 generateLink
// ─────────────────────────────────────────────
async function test4_secondGenerateLink() {
  console.log('\n── 測試 4：第二次 generateLink（同一 user）──');

  const { data, error } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email: TEST_EMAIL,
  });

  if (error) {
    console.error('❌ 第二次 generateLink 失敗：', error.message);
    return null;
  }

  console.log('✅ 可重複呼叫，拿到新 token');
  console.log('   hashed_token:', data.properties?.hashed_token?.substring(0, 20) + '...');
  return data.properties?.hashed_token;
}

// ─────────────────────────────────────────────
// 測試 5：用第二次 token 登入，確認可用
// ─────────────────────────────────────────────
async function test5_verifySecondToken(hashedToken) {
  console.log('\n── 測試 5：用第二次 token 登入 ──');

  const { data, error } = await client.auth.verifyOtp({
    token_hash: hashedToken,
    type: 'magiclink',
  });

  if (error) {
    console.error('❌ 第二次 token 登入失敗：', error.message);
    return null;
  }

  console.log('✅ 第二次 token 可用');
  return data.session;
}

// ─────────────────────────────────────────────
// 測試 6：deleteUser 後 session 是否失效
// ─────────────────────────────────────────────
async function test6_deleteUserAndCheckSession(session) {
  console.log('\n── 測試 6：deleteUser 後 session 是否失效 ──');

  // 刪除 user
  const { error: deleteError } = await admin.auth.admin.deleteUser(createdUserId);
  if (deleteError) {
    console.error('❌ deleteUser 失敗：', deleteError.message);
    return;
  }
  console.log('✅ deleteUser 成功');

  // 用已存在的 session access_token 呼叫 API，看是否還能用
  const userClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  await userClient.auth.setSession({
    access_token: session.access_token,
    refresh_token: session.refresh_token,
  });

  const { data, error: userError } = await userClient.auth.getUser();

  if (userError || !data.user) {
    console.log('✅ session 已失效（getUser 回傳錯誤）：', userError?.message ?? 'no user');
  } else {
    console.warn('⚠️  session 仍有效！user_id:', data.user.id);
    console.warn('   這表示 deleteUser 不會立即使現有 session 失效');
    console.warn('   需要另外呼叫 admin.signOut() 或等 JWT 過期（預設 1 小時）');
  }
}

// ─────────────────────────────────────────────
// 主流程
// ─────────────────────────────────────────────
async function main() {
  console.log('=== Guest Auth Spike ===');
  console.log('目標 Supabase:', SUPABASE_URL);

  const ok1 = await test1_createGuestUser();
  if (!ok1) return;

  const token1 = await test2_firstGenerateLink();
  if (!token1) return;

  const session = await test3_verifyOtp(token1);
  if (!session) return;

  const token2 = await test4_secondGenerateLink();
  if (!token2) return;

  await test5_verifySecondToken(token2);

  await test6_deleteUserAndCheckSession(session);

  console.log('\n=== Spike 完成 ===');
}

main().catch(console.error);
