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

## Milestone 4: 結算 & Dashboard（4.1~4.4 ✅）

**目標**：使用者可查看欠款、標記付款、在 Dashboard 看到個人總覽

### 4.1 結算 Domain Layer ✅
- [x] `SettlementEntity`、`BalanceEntity`、`OverallBalanceEntity`（plain class，遵循現有模式）
- [x] `SettlementRepository` abstract class
- [x] Use cases：`GetBalances`、`GetOverallBalances`、`GetSettlements`、`MarkSettled`

### 4.2 結算 Data Layer ✅
- [x] `SupabaseSettlementDataSource`：`get_user_balances` / `get_overall_balances` RPC、settlements CRUD
- [x] `SettlementRepositoryImpl`（try-catch → `AppResult<T>`）

### 4.3 結算 Presentation Layer ✅
- [x] `BalanceScreen`：群組內欠款總覽（帳務摘要卡 + 成員明細）
- [x] `SettlementHistoryScreen`：結算歷史（含空狀態、下拉刷新）
- [x] 手動標記已付款功能（確認 Dialog → markSettled → invalidate）
- [x] `BalanceCard`、`DebtRow`、`SettlementCard` widget
- [x] Riverpod providers：`balancesProvider`、`settlementsProvider`、`overallBalancesProvider`
- [x] 路由：`/groups/:groupId/balances`、`/groups/:groupId/settlements`
- [x] `GroupDetailScreen` 新增「帳務總覽」入口

### 4.4 Dashboard ✅
- [x] `DashboardScreen`：跨群組個人帳務總覽（替換 placeholder）
- [x] `BalanceSummaryCard` widget：淨額/應收/應付
- [x] `GroupBalanceRow` widget：各群組帳務列表（可點擊進入）
- [x] `RecentExpenseList` widget：最近 10 筆消費（含分類 icon）
- [x] `overallBalancesProvider`、`recentExpensesProvider`

### 4.5 離線快取 & 同步
- [ ] Hive box 結構建立（groups、expenses、balances、pending_sync、user_profile）
- [ ] `SyncOperation` model（freezed）
- [ ] 背景同步服務：pending_sync queue 處理
- [ ] 離線狀態 UI 提示

### 4.6 Realtime 訂閱 ✅
- [x] 群組消費即時更新（Supabase Realtime stream）
- [x] 群組成員變更即時更新
- [x] 結算變更即時更新
- [x] 進入/離開群組詳情頁自動管理訂閱（`ref.onDispose` 清理 channel）
- [x] 消費詳情頁即時同步（從 expensesProvider 衍生，共用 realtime 通道）

### 4.7 基本測試 ✅
- [x] Unit tests：均分計算、自訂比例計算、指定金額驗證（18 tests）
- [x] Unit tests：淨額計算邏輯（7 tests）
- [x] Repository tests：mock data source（5 tests）
- [x] Widget tests：SplitSummary 渲染 & badge 顯示（6 tests）

### 4.8 自訂比例 / 指定金額分帳（P1）✅
- [x] `SplitCalculator` 工具類：均分、自訂比例、指定金額計算邏輯
- [x] `AddExpenseScreen` SegmentedButton 切換分帳模式（均分 / 自訂比例 / 指定金額）
- [x] 自訂比例：輸入比例數字，即時計算分配金額
- [x] 指定金額：輸入各人金額，驗證加總是否等於總金額
- [x] 編輯消費時同步更新 splits（完整 update chain）
- [x] `SplitSummary` 顯示分帳類型 badge

**交付物**：4.1~4.4 + 4.6~4.8 完成 — 可查看欠款、標記付款、Dashboard 總覽、Realtime 即時同步、自訂分帳、40 項測試全過；4.5 離線快取待實作

---

## Milestone 5: UX 優化 ✅

**目標**：提升使用體驗，改善既有功能的直覺性與一致性

### 5.1 高優先 UX 修正 ✅
- [x] 消費列表「總金額」摘要：頂部群組消費總額 Card + 每日小計
- [x] 登入/註冊密碼顯示切換：眼睛 icon 切換 `obscureText`
- [x] 登出確認 dialog：防止誤觸
- [x] Social login loading 狀態：Google/Apple 登入時顯示 loading indicator

### 5.2 中優先 UX 修正 ✅
- [x] 硬編碼顏色改用 Theme：`Colors.green/red/grey` → `colorScheme.primary/error/onSurfaceVariant`（balance_card、settlement_card、debt_row、balance_screen、add_expense_screen）
- [x] 空狀態一致性：settlement_history、balance_screen 加入圖示 + 引導文字
- [x] 群組詳情快速摘要：顯示群組總支出 & 未結算金額
- [x] 加入群組 FAB icon：`vpn_key` → `group_add` 更直覺

**交付物**：✅ 8 項 UX 改善全部完成，`flutter analyze` 零錯誤

---

## Milestone 6: 搜尋篩選、收據附件、項目拆分 ✅

**目標**：實作三個新功能，對應 PRD P2 範圍

### 6.1 消費搜尋 & 篩選 ✅
- [x] `ExpenseListScreen` 改為 `ConsumerStatefulWidget`，新增可收合篩選面板
- [x] 關鍵字搜尋（描述文字）
- [x] 分類篩選（FilterChip 多選）
- [x] 付款人篩選（Dropdown）
- [x] 日期範圍篩選（DateRangePicker）
- [x] 篩選結果的總額 & 筆數顯示
- [x] 清除篩選按鈕 + 無結果空狀態
- [x] 純前端本地篩選，不需後端改動

### 6.2 收據/照片附件 ✅
- [x] `ExpenseEntity` 新增 `attachmentUrls` 欄位
- [x] `SupabaseExpenseDataSource` 新增 `uploadAttachment()`、`removeAttachment()`、`updateAttachmentUrls()`
- [x] `AddExpenseScreen` 新增拍照/相簿選取按鈕、附件縮圖 + 刪除
- [x] `ExpenseDetailScreen` 顯示附件圖片（水平滾動 + 點擊放大）
- [x] 新增 `image_picker` 依賴
- [x] SQL migration：`expenses` 表新增 `attachment_urls TEXT[]`
- [ ] **待手動處理**：Supabase Storage 建立 `receipts` bucket + RLS policy

### 6.3 項目拆分分帳 ✅
- [x] `SplitType.itemized` 新增至 enum
- [x] `ExpenseItemEntity` 新增（name、amount、sharedByUserIds）
- [x] `AddExpenseScreen` 新增項目拆分模式 UI（新增/刪除品項、品項金額、分攤者 FilterChip）
- [x] 項目金額合計驗證（必須等於總金額）
- [x] 自動彙算各成員分攤金額（均分各品項 → 加總 per user）
- [x] SQL migration：`expense_items` 表 + RLS policy
- [ ] **待手動處理**：執行 SQL migration 至 Supabase

**交付物**：✅ 3 個新功能全部完成，`flutter analyze` 零錯誤、48 項測試全過

---

## Milestone 7: UI 視覺翻新 & 新增消費 UX 優化

**目標**：整體視覺升級為 Apple 冷白系設計語言，新增消費改為漸進式揭露，將常用路徑縮短至 3 步

### 7.1 Design System & Theme 更新

- [ ] `app_theme.dart`：更新色彩系統（背景 #F5F5F7、卡片白色、主色 Indigo #4F46E5）
- [ ] `app_theme.dart`：Typography 調整（letterSpacing 收緊、fontWeight 層次）
- [ ] `app_theme.dart`：CardTheme（圓角 16px、無 elevation/shadow）
- [ ] `app_theme.dart`：AppBar（elevation:0、scrolledUnderElevation:0、背景融合底色）
- [ ] `app_theme.dart`：FilledButton（圓角 14px、高度 52px）
- [ ] `app_theme.dart`：NavigationBar（白底、0.5px 頂線、輕量 indicator）
- [ ] `app_theme.dart`：同步更新 Dark theme 對應設定

### 7.2 Shell & 全域元件更新

- [ ] `main_shell.dart`：NavigationBar 加上頂部細線分隔、更新 icon 至 rounded 系列
- [ ] `balance_summary_card.dart`：使用語義色（正值 #16A34A、負值 #DC2626）、卡片樣式升級
- [ ] `expense_card.dart`：視覺升級（圓角、分類色彩、排版改善）
- [ ] `group_card.dart`：視覺升級

### 7.3 新增消費畫面重構（Progressive Disclosure）

詳細規格見 `SPEC.md §9`

**[A] 金額區**
- [ ] 移除原本的 `TextFormField`，改為 `GestureDetector` 包裹的 Display widget
- [ ] 隱藏 `TextField` 用於接收輸入，`FocusNode` 管理 focus
- [ ] 金額 Display：fontSize 48、fontWeight 700、letterSpacing -1.0
- [ ] 輸入限制：`FilteringTextInputFormatter`，只允許數字與一個小數點、小數點後 ≤ 2 位
- [ ] 幣別：小型 Chip，de-emphasize 樣式，點擊彈出幣別選擇器

**[B1] 描述 + 分類卡**
- [ ] 描述改為無 border 的 TextField（卡片內整行），分類在下方
- [ ] 分類選擇器改為橫向可滑動 `ListView`（替換原 Wrap）
- [ ] 分類 Item：60×64px 圓角 tile，icon 上 label 下，選中主色填底
- [ ] 右側固定「+ 自訂」按鈕（不隨分類列表捲動）

**[B2] 付款人卡**
- [ ] 移除 `DropdownButton`，改為頭像 Chip 單選（顯示 CircleAvatar + 名字）
- [ ] 選中狀態：主色邊框 + ✓ icon

**[B3] 分攤卡**
- [ ] 分攤成員：移除 `CheckboxListTile`，改為頭像 Chip 多選
- [ ] 即時摘要文字（均分金額 / 非均分模式說明）
- [ ] 分帳方式改為 `ExpansionTile`（預設折疊）
- [ ] 折疊 header 顯示目前分帳方式摘要（含比例/金額細節）
- [ ] 展開後：RadioListTile 四選一，選中非均分後 inline 展開對應輸入 UI

**[B4] 更多選項**
- [ ] `ExpansionTile` 包裹：日期、備註、附件
- [ ] 日期移入此區（預設今天，不再佔用主表單空間）
- [ ] 編輯模式且有備註或附件時，預設 `initiallyExpanded: true`

**[C] 底部按鈕**
- [ ] 固定在 `SafeArea` 底部（不隨表單捲動）
- [ ] Disabled 條件：金額 ≤ 0 **或** 描述空白

**交付物**：視覺全面升級、新增消費常用路徑縮短至 3 步、`flutter analyze` 零錯誤、既有測試全過

---

## PRD 功能覆蓋對照

| PRD 功能 | 優先級 | Milestone | 狀態 |
|----------|--------|-----------|------|
| 帳號註冊/登入（Email + Google + Apple） | P0 | M1 | ✅ |
| 建立/加入群組（邀請碼） | P0 | M2 | ✅ |
| 新增消費記錄 | P0 | M3 | ✅ |
| 消費分類（含自訂分類） | P0 | M3 | ✅ |
| 均分分帳 | P0 | M3 | ✅ |
| 欠款總覽 | P0 | M4 | ✅ |
| 手動標記已付款 | P0 | M4 | ✅ |
| 基本 Dashboard | P0 | M4 | ✅ |
| 自訂比例 / 指定金額分帳 | P1 | M4 | ✅ |
| 多幣別支援 | P1 | M4 | ✅ |
| 搜尋用戶邀請 | P1 | M4 | ✅ |
| 最簡化轉帳演算法 | P1 | M4 | ✅ |
| 群組消費統計 | P1 | M4 | ✅ |
| Realtime 即時同步 | P1 | M4 | ✅ |
| 深色模式 | P1 | M4 | ✅ |
| 刪除群組 | P1 | M4 | ✅ |
| 項目拆分分帳 | P2 | M6 | ✅ |
| 收據/照片附件 | P2 | M6 | ✅ |
| 消費搜尋 & 篩選 | — | M6 | ✅ |
| UX 優化（8 項） | — | M5 | ✅ |
| UI 視覺翻新 (Apple 冷白系) | — | M7 | 🔲 待實作 |
| 新增消費 Progressive Disclosure | — | M7 | 🔲 待實作 |
| 推播通知 | P2 | — | ❌ 未開始 |
| i18n 多語系 | P2 | — | ❌ 未開始 |
| 金流串接 | P2 | — | ❌ 未開始 |
| 離線快取 & 同步 | — | — | ❌ 未開始 |
