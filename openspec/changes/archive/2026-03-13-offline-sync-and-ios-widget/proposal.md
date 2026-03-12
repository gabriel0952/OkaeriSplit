## Why

OkaeriSplit 目前為純線上運作（Remote-first），網路不穩時使用者無法記帳，且沒有桌面快速入口。兩項功能在 SPEC.md §10、§11 已完成詳細規格設計，是本階段最高優先的產品補完。

## What Changes

- **新增離線記帳**：無網路時仍可新增消費（存入本地 Hive pending queue），並瀏覽上次快取的群組/消費列表；網路恢復後自動同步 Supabase
- **新增 iOS Home Widget**：使用 WidgetKit Extension，桌面直接顯示最多 3 個群組，點擊 [+ 記帳] 深度連結開啟 AddExpenseScreen
- **新增連線狀態感知**：引入 `connectivity_plus`，全域偵測線上/離線狀態並驅動 Repository 切換策略
- **新增 Hive 快取層**：groups_cache、expenses_cache、group_members_cache、pending_expenses 四個 Box
- **新增 `home_widget` 套件**：Flutter ↔ Native App Group 橋接，供 Widget Extension 讀取群組資料

## Capabilities

### New Capabilities

- `offline-expense-sync`: 離線新增消費（Hive pending queue）、自動偵測網路並上傳、消費列表「待同步 N 筆」Badge
- `hive-cache-layer`: 群組/消費/成員列表本地快取，提供離線瀏覽能力
- `ios-home-widget`: WidgetKit Extension + HomeWidgetService，桌面顯示群組列表並支援深度連結記帳

### Modified Capabilities

- `add-expense`: 離線模式下付款人/分攤成員改從 group_members_cache 讀取；新增消費成功後顯示「已離線儲存」SnackBar

## Impact

- **新套件**：`connectivity_plus`、`home_widget`（pubspec.yaml）
- **新 Hive Box**：groups_cache、expenses_cache、group_members_cache、pending_expenses
- **新服務**：`ConnectivityService`、`SyncService`、`HomeWidgetService`（lib/core/services/）
- **新 Repository**：`PendingExpenseRepository`（lib/features/expenses/data/）
- **修改**：`GroupRepositoryImpl`、`ExpenseRepositoryImpl`（加入 isOnline 判斷與快取讀寫）
- **iOS 原生**：新增 Widget Extension Target（ios/OkaeriSplitWidget/）、App Group Capability
- **路由**：AppRouter 新增 `add-expense` deep link path 解析
