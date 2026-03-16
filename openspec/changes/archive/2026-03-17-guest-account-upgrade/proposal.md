## Why

訪客目前進入群組後完全無法主動離開，也無法轉換成正式帳號，形成「進得去、出不來」的死胡同體驗。隨著訪客功能上線，這兩個出口需要補齊，讓訪客身份的生命週期完整。

## What Changes

- **新增「退出訪客模式」入口**：訪客可在群組頁主動登出，回到登入畫面，session 清除、Hive cache 清除。
- **新增「升級為正式帳號」流程**：訪客可選擇輸入 email 與密碼（或綁定 Google / Apple），將臨時訪客帳號轉換為永久正式帳號，保留原群組成員身份與所有資料。
- **新增 Edge Function `upgrade_guest_account`**：負責更新 Supabase Auth 使用者的 email、清除 `is_guest` 旗標，並在升級前驗證 email 未被其他帳號占用。
- **群組封存邏輯調整**：封存時排除已升級為正式帳號的前訪客，不得誤刪。

## Capabilities

### New Capabilities
- `guest-exit`: 訪客登出流程 — 在群組頁提供退出按鈕，清除 session 與本地快取，導回登入畫面
- `guest-upgrade`: 訪客帳號升級流程 — 引導訪客設定 email/密碼或綁定 OAuth，將帳號轉為正式身份

### Modified Capabilities
- `group-members`: 群組封存時的訪客清理邏輯需排除已升級帳號（`is_guest = false`）

## Impact

- **前端**：`GroupDetailScreen`（新增按鈕）、新增 `GuestUpgradeScreen`、`app_router.dart`（升級後路由調整）、`supabase_auth_datasource.dart`（升級方法）
- **後端**：新增 `upgrade_guest_account` Edge Function；`archive_group` Edge Function 邏輯調整
- **資料庫**：`profiles` 表的 `is_guest` 欄位由 `true` 轉 `false`；auth user 的 email 更新為真實 email
- **無 breaking change**：訪客不升級的話行為完全不變
