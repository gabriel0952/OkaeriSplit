# OkaeriSplit MVP 開發計畫

> 對應 PRD P0 所有功能，分為 4 個 Milestone 依序開發。
> 每個 Milestone 結束時應有可運行的交付物。

---

## Milestone 1: 專案初始化 & 基礎建設 ✅

**目標**：專案骨架就位，Auth 流程可跑通

### 1.1 Flutter 專案初始化
- [x] 建立 Flutter 專案（`app/`，iOS + Android）
- [x] 安裝依賴：`flutter_riverpod`、`go_router`、`freezed`、`fpdart`、`supabase_flutter`、`hive_flutter`、`json_annotation`
- [x] 設定 `build_runner` / `freezed` code generation
- [x] 建立目錄結構（`core/`、`features/`、`routing/`）

### 1.2 Supabase 設定 & DB Migration
- [x] 建立 Supabase 專案（Tokyo region）
- [x] 產生 SQL migration 檔（`supabase/migrations/001_initial_schema.sql`）
  - [x] 6 張表（profiles、groups、group_members、expenses、expense_splits、settlements）
  - [x] `handle_new_user()` trigger（已修復 search_path）
  - [x] `update_updated_at()` trigger
  - [x] 所有表的 RLS + policies
  - [x] RPC functions：`create_group`、`create_expense`、`join_group_by_code`、`get_user_balances`、`get_overall_balances`
- [x] 執行 migration 至 Supabase
- [x] 設定 Auth providers（Email 已啟用，關閉 email confirmation）

### 1.3 Core 模組
- [x] `core/theme/`：Light/Dark theme 設定，iOS Cupertino 風格支援
- [x] `core/errors/`：`Failure` sealed class、`AppResult<T>` typedef
- [x] `core/constants/`：Supabase placeholder URL/Key、ExpenseCategory / GroupType / SplitType enum
- [x] `core/widgets/`：`AppLoadingWidget`、`AppErrorWidget`

### 1.4 Auth Feature
- [x] `auth/domain/`：UserEntity、AuthRepository abstract class、SignIn/SignUp/SignOut/GetCurrentUser use cases
- [x] `auth/data/`：SupabaseAuthDataSource（含 Google/Apple OAuth）、AuthRepositoryImpl
- [x] `auth/presentation/`：LoginScreen、RegisterScreen、authProvider/authStateProvider
- [x] SocialLoginButton widget（Google + Apple Sign-In）
- [x] 路由守衛：未登入導向 `/login`

### 1.5 路由 & App Shell
- [x] `routing/app_router.dart`：GoRouter + StatefulShellRoute（含 auth redirect）
- [x] `MainShell`：底部導航（總覽 / 群組 / 我的）
- [x] Placeholder screens：DashboardScreen、GroupListScreen、ProfileScreen

**交付物**：✅ `flutter analyze` 零錯誤，App 可啟動顯示 Login，登入後進入 3-tab MainShell

---

## Milestone 2: 群組管理 ✅

**目標**：使用者可建立群組、透過邀請碼加入群組、查看成員

### 2.1 群組 Domain Layer
- [x] `GroupEntity`、`GroupMemberEntity`
- [x] `GroupRepository` abstract class
- [x] Use cases：`CreateGroup`、`GetGroups`、`GetGroupDetail`、`GetGroupMembers`、`JoinGroupByCode`、`LeaveGroup`

### 2.2 群組 Data Layer
- [x] `SupabaseGroupDataSource`：呼叫 `create_group` RPC、`join_group_by_code` RPC、CRUD
- [x] `GroupRepositoryImpl`（暫不做 Hive 快取，M4 再加）

### 2.3 群組 Presentation Layer
- [x] `GroupListScreen`：顯示已加入群組列表（含空狀態、下拉刷新）
- [x] `CreateGroupScreen`：群組名稱、類型 SegmentedButton、幣別下拉
- [x] `GroupDetailScreen`：群組資訊、成員列表、消費列表入口（placeholder）
- [x] `JoinGroupDialog`：輸入 6 碼邀請碼加入
- [x] `GroupCard` widget、`MemberAvatar` widget
- [x] Riverpod providers：`groupsProvider`、`groupDetailProvider`、`groupMembersProvider`

### 2.4 群組成員管理
- [x] 顯示群組邀請碼（可複製分享）
- [x] 成員退出群組功能（owner 不可退出）

### 2.5 路由
- [x] `/groups/create` → CreateGroupScreen
- [x] `/groups/:groupId` → GroupDetailScreen

**交付物**：✅ 可建立群組、用邀請碼加入、查看/退出群組、查看成員列表

---

## Milestone 3: 記帳 & 分帳 ✅

**目標**：使用者可在群組內新增消費、均分分帳、查看/編輯/刪除消費

### 3.1 消費 Domain Layer
- [x] `ExpenseEntity`、`ExpenseSplitEntity`
- [x] `ExpenseRepository` abstract class
- [x] Use cases：`CreateExpense`、`GetExpenses`、`GetExpenseDetail`、`UpdateExpense`、`DeleteExpense`

### 3.2 消費 Data Layer
- [x] `SupabaseExpenseDataSource`：呼叫 `create_expense` RPC、CRUD、camelCase↔snake_case 轉換
- [x] `ExpenseRepositoryImpl`（try-catch → `AppResult<T>`）
- [ ] `HiveExpenseDataSource`：本地快取（延至 M4）

### 3.3 消費 Presentation Layer
- [x] `AddExpenseScreen`：金額、付款人、日期、備註、分類、均分成員勾選（新增+編輯共用）
- [x] `ExpenseListScreen`：群組消費列表（按日期排序、空狀態、下拉刷新）
- [x] `ExpenseDetailScreen`：消費明細 & 分帳詳情、編輯/刪除（僅付款人可操作）
- [x] `CategoryPicker` widget：6 種消費分類 ChoiceChip 選擇器
- [x] `SplitSummary` widget：每位成員分攤金額顯示
- [x] `ExpenseCard` widget：分類 icon、金額、付款人、日期
- [x] Riverpod providers：`expensesProvider`、`expenseDetailProvider` + 5 個 use case provider

### 3.4 均分計算邏輯
- [x] 選擇參與分帳的成員（可取消勾選）
- [x] 自動計算每人分攤金額（處理除不盡的尾差，餘數分配給第一位成員）

### 3.5 路由 & 整合
- [x] `/groups/:groupId/expenses` → ExpenseListScreen
- [x] `/groups/:groupId/add-expense` → AddExpenseScreen（新增模式）
- [x] `/groups/:groupId/expenses/:expenseId` → ExpenseDetailScreen
- [x] `/groups/:groupId/expenses/:expenseId/edit` → AddExpenseScreen（編輯模式）
- [x] `GroupDetailScreen` 消費入口連結

**交付物**：✅ 可新增消費（均分）、查看消費列表與詳情、編輯/刪除消費、`flutter analyze` 零錯誤

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
