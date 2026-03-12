## 1. SkeletonBox 基礎元件

- [x] 1.1 在 `lib/core/widgets/skeleton_box.dart` 建立 `SkeletonBox` Widget，使用 `AnimatedBuilder` + `LinearGradient` shimmer 動畫（左至右，1.5s 週期），支援亮/暗色主題
- [x] 1.2 在 `lib/core/widgets/skeleton_box.dart` 建立 `ExpenseListSkeleton`（5 行，每行含 44×44 圓角方形 + 兩行文字佔位 + 右側金額佔位）
- [x] 1.3 在 `lib/core/widgets/skeleton_box.dart` 建立 `GroupListSkeleton`（3 張仿 GroupCard 形狀的骨架卡片）
- [x] 1.4 在 `lib/core/widgets/skeleton_box.dart` 建立 `BalanceSkeleton`（頂部摘要卡佔位 + 2 行債務佔位）

## 2. 替換各頁面 Loading 狀態

- [x] 2.1 `expense_list_screen.dart`：loading 時改用 `ExpenseListSkeleton`
- [x] 2.2 `group_list_screen.dart`：loading 時改用 `GroupListSkeleton`
- [x] 2.3 `balance_screen.dart`：loading 時改用 `BalanceSkeleton`
- [x] 2.4 `dashboard_screen.dart`：overallAsync loading 時改用 `BalanceSkeleton` 佔位（或專用 DashboardSkeleton），recentAsync loading 時改用 `ExpenseListSkeleton`

## 3. EmptyStateWidget 通用元件

- [x] 3.1 在 `lib/core/widgets/empty_state_widget.dart` 建立 `EmptyStateWidget`，接受 `icon`、`title`、`subtitle?`、`action?` 參數，實作垂直居中佈局
- [x] 3.2 `expense_list_screen.dart`：data 為空時改用 `EmptyStateWidget`（圖示 `receipt_long_outlined`，title「尚無消費紀錄」，subtitle「點擊 + 新增第一筆消費」）
- [x] 3.3 `group_list_screen.dart`：data 為空時改用 `EmptyStateWidget`（圖示 `group_outlined`，title「還沒有群組」，subtitle + 「建立群組」action 按鈕）
- [x] 3.4 `settlement_history_screen.dart`：data 為空時改用 `EmptyStateWidget`（圖示 `handshake_outlined`，title「尚無結算紀錄」）
- [x] 3.5 `balance_screen.dart`：balances 全為 0 或 data 為空時改用 `EmptyStateWidget`（圖示 `check_circle_outline`，title「帳目已清空」，subtitle「群組內沒有未清的帳款」）

## 4. 頁面過場動畫

- [x] 4.1 在 `lib/routing/app_router.dart` 中，將所有二級 `GoRoute`（groups/create、:groupId、expenses、:expenseId、edit、add-expense、balances、settlements、stats、/profile）的 `builder:` 改為 `pageBuilder:`，返回 `CustomTransitionPage`，過場使用 `SlideTransition`（from right, Offset(1,0)→Offset.zero）+ `FadeTransition` 組合，動畫時長 250ms，曲線 `Curves.easeInOut`
- [x] 4.2 確認根頁面 `StatefulShellRoute` 及各 branch 首頁（`/dashboard`、`/groups`、`/profile`）保持預設 builder，不套用 slide 動畫

## 5. ExpandableFab 元件

- [x] 5.1 在 `lib/core/widgets/expandable_fab.dart` 建立 `ExpandableFab` 元件，主 FAB 展開後圖示從 `add` 旋轉至 `close`（`AnimatedRotation`），展開動畫使用 `AnimatedContainer` + `FadeTransition`（200ms）
- [x] 5.2 建立 `ExpandableFabChild` 資料類別（`icon`、`label`、`onPressed`）及對應的 child 按鈕 Widget（小型 FAB + 右側文字標籤）
- [x] 5.3 `ExpandableFab` 展開時在畫面上方加半透明遮罩（`ModalBarrier`），點擊遮罩可收合
- [x] 5.4 `group_list_screen.dart`：將 `floatingActionButton` 改為 `ExpandableFab`，子項目為「加入群組」（`group_add_outlined`）和「建立群組」（`add`），分別觸發原有的 showModalBottomSheet 和 context.push('/groups/create')

## 6. 微互動動畫

- [x] 6.1 `add_expense_screen.dart`：線上儲存成功後，在 pop 前以 `ScaffoldMessenger.of(context).showSnackBar` 顯示含勾選圖示的「消費已新增」SnackBar（duration 1.5s）
- [x] 6.2 `add_expense_screen.dart`：離線儲存成功後，顯示含 `cloud_upload_outlined` 圖示的「已排程，連線後自動同步」SnackBar
- [x] 6.3 `expense_list_screen.dart`：以 `AnimatedSwitcher`（300ms）包裹消費列表 widget，列表長度變化時（刪除/新增後）自動觸發淡入淡出過渡動畫
