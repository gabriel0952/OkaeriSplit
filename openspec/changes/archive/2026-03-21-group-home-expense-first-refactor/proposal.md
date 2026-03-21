## Why

進入群組後，使用者最常做的事是查看和管理消費紀錄，但目前主要顯示的是群組詳情（成員列表、群組資訊），使用者必須額外跳轉才能看到消費紀錄，造成操作不直覺、流程不流暢。

## What Changes

- 將群組主頁（`/groups/:groupId`）從「群組詳情頁」改為「消費紀錄頁」，消費清單成為進入群組後的第一畫面
- AppBar 頂部顯示群組名稱 + 簡要結算資訊（誰欠誰多少），讓使用者快速掌握現況
- 保留 FAB 快速新增消費功能
- AppBar 右上角新增「設定」入口圖示
- 新建「群組設定頁」（`/groups/:groupId/settings`），整合以下原本散落在群組詳情的功能：
  - 群組基本資訊（名稱、描述、貨幣）
  - 成員管理（邀請、移除成員）
  - 結算管理入口
  - 刪除群組 / 離開群組
- 原有的 `GroupDetailScreen` 功能被拆分：部分整合進新主頁頂部摘要，其餘移至設定頁
- 路由結構調整：`/groups/:groupId` 直接對應消費紀錄邏輯，`/groups/:groupId/settings` 為新路由

## Capabilities

### New Capabilities
- `group-home-expense-first`: 群組主頁重構為以消費紀錄為核心的頁面，頂部顯示群組摘要與結算資訊
- `group-settings-page`: 新的群組設定頁，整合成員管理與群組管理功能

### Modified Capabilities
- `group-members`: 成員管理的入口從群組詳情頁移至群組設定頁，UI 操作流程有所調整

## Impact

- `app/lib/features/groups/presentation/screens/group_detail_screen.dart`：功能拆分，頂部摘要保留、其餘移至設定頁
- `app/lib/features/expenses/presentation/screens/expense_list_screen.dart`：成為群組主頁，需整合群組摘要 AppBar
- `app/lib/routing/app_router.dart`：路由結構調整，新增 `/groups/:groupId/settings` 路由
- 新增 `app/lib/features/groups/presentation/screens/group_settings_screen.dart`
- 現有的「結算」、「統計」頁面的導航入口需從詳情頁改為設定頁或主頁 AppBar
