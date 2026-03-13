## 1. DB Migration

- [x] 1.1 `profiles` 新增欄位
  ```sql
  ALTER TABLE profiles
    ADD COLUMN is_guest BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN claim_code TEXT UNIQUE;
  CREATE INDEX idx_profiles_claim_code ON profiles(claim_code)
    WHERE claim_code IS NOT NULL;
  ```

- [x] 1.2 新增 `is_guest_user()` 輔助函式（供 RLS 使用）
  ```sql
  CREATE OR REPLACE FUNCTION is_guest_user()
  RETURNS BOOLEAN AS $$
    SELECT COALESCE(
      (SELECT is_guest FROM profiles WHERE id = auth.uid()), false
    );
  $$ LANGUAGE sql SECURITY DEFINER STABLE;
  ```

- [x] 1.3 更新 RLS 政策，所有寫入操作加入 `AND NOT is_guest_user()` 限制：
  - `expenses_insert` / `expenses_update` / `expenses_delete`
  - `expense_splits_insert` / `expense_splits_update` / `expense_splits_delete`
  - `group_members_insert` / `group_members_delete`
  - `settlements_insert`

- [x] 1.4 執行 migration 至 Supabase

## 2. Edge Functions

- [x] 2.1 建立 `supabase/functions/create_guest_member/index.ts`
  - 接收：`{ group_id, display_name }`
  - 驗證呼叫者是該群組成員
  - 建立 Supabase auth user（fake email + `email_confirm: true`）
  - 建立 profile（`is_guest: true`，產生 6 位 claim_code）
  - 加入 `group_members`
  - 回傳：`{ claim_code }`

- [x] 2.2 建立 `supabase/functions/claim_guest_member/index.ts`
  - 接收：`{ group_invite_code, claim_code }`
  - Rate limiting：同一 IP 每分鐘最多 5 次
  - 驗證 `group_invite_code` 對應群組存在
  - 驗證 `claim_code` 屬於該群組的成員
  - 呼叫 `admin.generateLink({ type: 'magiclink', email: guest_email })`
  - 回傳：`{ hashed_token }`

- [x] 2.3 部署兩個 Edge Functions 至 Supabase（均加 `--no-verify-jwt`）

## 3. Flutter — 訪客登入流程

- [x] 3.1 確認 `share_plus` 已在 `pubspec.yaml`（若無則新增並 `flutter pub get`）

- [x] 3.2 `LoginScreen` 新增「我是訪客」次要按鈕，導向訪客登入頁

- [x] 3.3 建立 `GuestLoginScreen`（`lib/features/auth/presentation/screens/`）
  - Step 1：輸入群組代碼（6 位，驗證群組存在）
  - Step 2：輸入訪客代碼（6 位）
  - 呼叫 `claim_guest_member` Edge Function 取得 `hashed_token`
  - 呼叫 `supabase.auth.verifyOtp({ token_hash, type: 'magiclink' })` 完成登入

- [x] 3.4 `app_router.dart` 新增 `/guest-login` 路由

- [x] 3.5 路由守衛：訪客登入後只能進入唯讀的群組瀏覽，不能進入一般 Dashboard

## 4. Flutter — 訪客瀏覽模式

- [x] 4.1 `authStateProvider` / `authRepositoryProvider` 加入 `isGuest` getter（讀 `profiles.is_guest`）

- [x] 4.2 建立 `isGuestProvider`（`Provider<bool>`），供各畫面判斷當前用戶是否為訪客

- [x] 4.3 訪客進入 APP 後直接導向對應群組的 `GroupDetailScreen`（跳過 Dashboard / 群組列表）

- [x] 4.4 `GroupDetailScreen` 訪客模式
  - AppBar 顯示「訪客瀏覽」badge
  - 隱藏所有寫入操作入口（新增消費、邀請成員、結算等）

- [x] 4.5 `ExpenseListScreen` 訪客模式
  - 隱藏新增消費 FAB

- [x] 4.6 `BalanceScreen` 訪客模式
  - 顯示帳務資訊（唯讀），隱藏「標記已付款」按鈕

## 5. Flutter — 建立虛擬成員（現有用戶）

- [x] 5.1 `InviteMemberDialog`（或群組成員管理頁）新增「新增訪客」入口

- [x] 5.2 建立 `AddGuestMemberDialog`
  - 輸入顯示名稱
  - 呼叫 `create_guest_member` Edge Function
  - 成功後顯示訪客代碼 + 複製 / 分享按鈕（`share_plus`）

- [x] 5.3 成員列表區分正式成員與虛擬成員
  - 虛擬成員顯示「訪客」tag
  - 未認領者顯示「待認領」狀態

## 6. Flutter — 修改現有功能支援虛擬成員

- [x] 6.1 `AddExpenseScreen` 付款人選單：包含虛擬成員（`is_guest` 用戶）

- [x] 6.2 `AddExpenseScreen` 分攤成員選單：同上

## 7. 訪客帳號清理

> 已移至 `group-archive` change 一併實作
