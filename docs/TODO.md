# OkaeriSplit MVP 開發計畫

> 對應 PRD P0 所有功能，分為 4 個 Milestone 依序開發。
> 每個 Milestone 結束時應有可運行的交付物。

---

## Milestone 1: 專案初始化 & 基礎建設

**目標**：專案骨架就位，Auth 流程可跑通

### 1.1 Flutter 專案初始化
- [ ] 建立 Flutter 專案，設定 Android minSdk 24
- [ ] 安裝依賴：`flutter_riverpod`、`go_router`、`freezed`、`fpdart`、`supabase_flutter`、`hive_flutter`、`json_annotation`
- [ ] 設定 `build_runner` / `freezed` code generation
- [ ] 建立目錄結構（`core/`、`features/`、`routing/`）

### 1.2 Supabase 設定 & DB Migration
- [ ] 建立 Supabase 專案
- [ ] 執行 DB migration：建立 6 張表（profiles、groups、group_members、expenses、expense_splits、settlements）
- [ ] 建立 `handle_new_user()` trigger
- [ ] 建立 `update_updated_at()` trigger
- [ ] 啟用所有表的 RLS
- [ ] 建立所有 RLS policies（含 group_members DELETE、expense_splits UPDATE/DELETE）
- [ ] 建立 RPC functions：`create_group`、`create_expense`、`join_group_by_code`、`get_user_balances`、`get_overall_balances`
- [ ] 設定 Auth providers（Email、Google、Apple）

### 1.3 Core 模組
- [ ] `core/theme/`：Light/Dark theme 設定，iOS Cupertino 風格支援
- [ ] `core/errors/`：`Failure` class、`Either` typedef
- [ ] `core/constants/`：Supabase URL/Key、enum 映射
- [ ] `core/widgets/`：共用 loading/error widgets

### 1.4 Auth Feature
- [ ] `auth/domain/`：User entity、AuthRepository abstract class、SignIn/SignUp/SignOut use cases
- [ ] `auth/data/`：SupabaseAuthDataSource、AuthRepositoryImpl
- [ ] `auth/presentation/`：LoginScreen、RegisterScreen、authProvider/authStateProvider
- [ ] Social login buttons（Google + Apple Sign-In）
- [ ] 路由守衛：未登入導向 `/login`

### 1.5 路由 & App Shell
- [ ] `routing/app_router.dart`：GoRouter 設定（含 auth redirect）
- [ ] `MainShell`：底部導航（Dashboard / 群組 / 我的）
- [ ] Placeholder screens for Dashboard、GroupList、Profile

**交付物**：可註冊、登入、登出，底部導航可切換 placeholder 頁面

---

## Milestone 2: 群組管理

**目標**：使用者可建立群組、透過邀請碼加入群組、查看成員

### 2.1 群組 Domain Layer
- [ ] `Group` entity、`GroupMember` entity
- [ ] `GroupRepository` abstract class
- [ ] Use cases：`CreateGroup`、`GetGroups`、`JoinGroupByCode`、`LeaveGroup`

### 2.2 群組 Data Layer
- [ ] `GroupModel`（freezed）、`GroupMemberModel`（freezed）
- [ ] `SupabaseGroupDataSource`：呼叫 `create_group` RPC、`join_group_by_code` RPC、CRUD
- [ ] `HiveGroupDataSource`：本地快取
- [ ] `GroupRepositoryImpl`：remote-first read、local-first write

### 2.3 群組 Presentation Layer
- [ ] `GroupListScreen`：顯示已加入群組列表
- [ ] `CreateGroupScreen`：群組名稱、類型選擇、幣別選擇
- [ ] `GroupDetailScreen`：群組資訊、成員列表、消費列表入口
- [ ] `JoinGroupDialog`：輸入邀請碼加入
- [ ] `GroupCard` widget、`MemberAvatar` widget
- [ ] Riverpod providers：`groupsProvider`、`groupDetailProvider`

### 2.4 群組成員管理
- [ ] 顯示群組邀請碼（可複製分享）
- [ ] 成員退出群組功能

**交付物**：可建立群組、用邀請碼加入、查看/退出群組、查看成員列表

---

## Milestone 3: 記帳 & 分帳

**目標**：使用者可在群組內新增消費、均分分帳、查看/編輯/刪除消費

### 3.1 消費 Domain Layer
- [ ] `Expense` entity、`ExpenseSplit` entity
- [ ] `ExpenseRepository` abstract class
- [ ] Use cases：`CreateExpense`、`GetExpenses`、`UpdateExpense`、`DeleteExpense`

### 3.2 消費 Data Layer
- [ ] `ExpenseModel`（freezed）、`ExpenseSplitModel`（freezed）
- [ ] `SupabaseExpenseDataSource`：呼叫 `create_expense` RPC、CRUD
- [ ] `HiveExpenseDataSource`：本地快取
- [ ] `ExpenseRepositoryImpl`

### 3.3 消費 Presentation Layer
- [ ] `AddExpenseScreen`：金額、付款人、日期、備註、分類、分帳方式
- [ ] `ExpenseListScreen`：群組消費列表（按日期排序）
- [ ] `ExpenseDetailScreen`：消費明細 & 分帳詳情
- [ ] 消費編輯功能（複用 AddExpenseScreen）
- [ ] 消費刪除功能（含確認 dialog）
- [ ] `CategoryPicker` widget：6 種消費分類選擇器
- [ ] `SplitMethodSelector` widget：均分計算邏輯
- [ ] `ExpenseCard` widget
- [ ] Riverpod providers：`expensesProvider`、`addExpenseProvider`

### 3.4 均分計算邏輯
- [ ] 選擇參與分帳的成員
- [ ] 自動計算每人分攤金額（處理除不盡的尾差）

**交付物**：可新增消費（均分）、查看消費列表與詳情、編輯/刪除消費

---

## Milestone 4: 結算 & Dashboard

**目標**：使用者可查看欠款、標記付款、在 Dashboard 看到個人總覽

### 4.1 結算 Domain Layer
- [ ] `Settlement` entity、`Balance` entity
- [ ] `SettlementRepository` abstract class
- [ ] Use cases：`GetBalances`、`MarkSettled`

### 4.2 結算 Data Layer
- [ ] `SettlementModel`（freezed）、`BalanceModel`（freezed）
- [ ] `SupabaseSettlementDataSource`：呼叫 `get_user_balances` RPC、settlements CRUD
- [ ] `SettlementRepositoryImpl`

### 4.3 結算 Presentation Layer
- [ ] `BalanceScreen`：群組內欠款總覽（誰欠誰多少）
- [ ] `SettlementHistoryScreen`：結算歷史
- [ ] 手動標記已付款功能（from_user → to_user）
- [ ] `BalanceCard` widget、`DebtRow` widget
- [ ] Riverpod providers：`balancesProvider`、`settlementsProvider`

### 4.4 Dashboard
- [ ] `DashboardScreen`：跨群組個人帳務總覽（呼叫 `get_overall_balances` RPC）
- [ ] `BalanceSummaryCard` widget：總欠款/總應收
- [ ] `RecentExpenseList` widget：最近消費
- [ ] `overallBalanceProvider`

### 4.5 離線快取 & 同步
- [ ] Hive box 結構建立（groups、expenses、balances、pending_sync、user_profile）
- [ ] `SyncOperation` model（freezed）
- [ ] 背景同步服務：pending_sync queue 處理
- [ ] 離線狀態 UI 提示

### 4.6 Realtime 訂閱
- [ ] 群組消費即時更新（Supabase Realtime stream）
- [ ] 群組成員變更即時更新
- [ ] 進入/離開群組詳情頁自動管理訂閱

### 4.7 基本測試
- [ ] Unit tests：均分計算、淨額計算邏輯
- [ ] Repository tests：mock data source
- [ ] Widget tests：關鍵 screens

**交付物**：完整 MVP — 可查看欠款、標記付款、Dashboard 總覽、離線快取、即時同步

---

## PRD P0 功能覆蓋對照

| PRD P0 功能 | Milestone | 任務 |
|-------------|-----------|------|
| 帳號註冊/登入（Email + Google + Apple） | M1 | 1.4 Auth Feature |
| 建立/加入群組（邀請碼） | M2 | 2.1–2.4 |
| 新增消費記錄 | M3 | 3.1–3.3 |
| 消費分類 | M3 | 3.3 CategoryPicker |
| 均分分帳 | M3 | 3.4 均分計算 |
| 欠款總覽 | M4 | 4.3 BalanceScreen |
| 手動標記已付款 | M4 | 4.3 標記付款 |
| 基本 Dashboard | M4 | 4.4 Dashboard |
