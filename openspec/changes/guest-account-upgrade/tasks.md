## 1. 後端：upgrade_guest_account Edge Function

- [x] 1.1 建立 `supabase/functions/upgrade_guest_account/index.ts`，接收 `{ email, password, display_name }`
- [x] 1.2 驗證 email 格式與密碼長度（≥ 8 字元），不符合回傳 400
- [x] 1.3 查詢 `auth.users` 確認 email 未被其他帳號占用，已存在回傳 409
- [x] 1.4 呼叫 `admin.updateUser(userId, { email, password, email_confirm: true, user_metadata: { is_guest: false, display_name } })`
- [x] 1.5 UPDATE `profiles` 設定 `is_guest = false`、`display_name = $display_name`
- [x] 1.6 回傳 `{ success: true }`

## 2. 後端：archive_group Edge Function 調整

- [x] 2.1 將封存時清理訪客的查詢條件加上 `profiles.is_guest = true`，排除已升級帳號

## 3. 前端：Auth DataSource 新增升級方法

- [x] 3.1 在 `supabase_auth_datasource.dart` 新增 `upgradeGuestAccount({ email, password, displayName })` 方法，呼叫 Edge Function 並在成功後執行 `refreshSession()`

## 4. 前端：訪客退出功能

- [x] 4.1 在 `GroupDetailScreen` AppBar 訪客模式下新增退出 icon button（`Icons.logout` 或 `Icons.exit_to_app`）
- [x] 4.2 點擊後顯示確認 dialog（「確定要退出訪客模式嗎？」，含取消/退出按鈕）
- [x] 4.3 確認後呼叫 `signOut()`，清除 Hive `guest_group_id`，router 自動導向 `/login`

## 5. 前端：GuestUpgradeScreen

- [x] 5.1 建立 `lib/features/auth/presentation/screens/guest_upgrade_screen.dart`，含 email、密碼、顯示名稱三個欄位
- [x] 5.2 前端驗證：email 格式、密碼 ≥ 8 字元、顯示名稱非空
- [x] 5.3 呼叫 `upgradeGuestAccount()`，loading 狀態處理
- [x] 5.4 成功後導向 `/dashboard`
- [x] 5.5 錯誤處理：409 顯示「此 email 已被其他帳號使用」，其他錯誤顯示通用錯誤訊息

## 6. 前端：升級入口 UI

- [x] 6.1 在 `GroupDetailScreen` 訪客模式的 AppBar 新增「建立正式帳號」按鈕（退出按鈕旁）
- [x] 6.2 在 `app_router.dart` 新增 `/guest-upgrade` 路由，指向 `GuestUpgradeScreen`
- [x] 6.3 確認升級後 `isGuest = false` 時，router redirect 不再將使用者鎖回群組頁
