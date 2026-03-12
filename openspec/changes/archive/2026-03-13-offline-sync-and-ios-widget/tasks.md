## 1. 安裝套件與初始化 Hive Box

- [x] 1.1 在 `pubspec.yaml` 新增 `connectivity_plus`、`home_widget` 套件並執行 `flutter pub get`
- [x] 1.2 在 `main.dart`（或 Hive 初始化處）新增開啟 `groups_cache`、`expenses_cache`、`group_members_cache`、`pending_expenses` 四個 Box
- [x] 1.3 在 `main.dart` 呼叫 `HomeWidgetService().init()`（setAppGroupId）

## 2. ConnectivityService

- [x] 2.1 在 `lib/core/services/connectivity_service.dart` 建立 `ConnectivityService`，使用 `connectivity_plus` 提供 `Stream<bool> isOnlineStream` 與 `bool get isOnline`
- [x] 2.2 在 `lib/core/providers/connectivity_provider.dart` 建立 `connectivityProvider`（`StreamProvider<bool>`）

## 3. Hive 快取 DataSource

- [x] 3.1 實作 `HiveGroupDataSource`（`lib/features/groups/data/datasources/`）：`saveGroups()`、`getGroups()`、`saveMembers()`、`getMembers(groupId)`
- [x] 3.2 實作 `HiveExpenseDataSource`（`lib/features/expenses/data/datasources/`）：`saveExpenses(groupId, expenses)`、`getExpenses(groupId)`

## 4. 修改 Repository 加入快取策略

- [x] 4.1 修改 `GroupRepositoryImpl.getGroups()`：isOnline → 讀 Supabase → 寫 groups_cache → 回傳；否則讀 groups_cache
- [x] 4.2 修改 `GroupRepositoryImpl.getMembers(groupId)`：isOnline → 讀 Supabase → 寫 group_members_cache → 回傳；否則讀 group_members_cache
- [x] 4.3 修改 `ExpenseRepositoryImpl.getExpenses(groupId)`：isOnline → 讀 Supabase → 寫 expenses_cache → 回傳；否則讀 expenses_cache

## 5. PendingExpenseRepository 與 PendingExpenseDto

- [x] 5.1 在 `lib/features/expenses/data/` 建立 `PendingExpenseDto`（含 localId、groupId、paidBy、amount、currency、category、description、note、expenseDate、splits、pendingAt）
- [x] 5.2 建立 `PendingExpenseRepository`：`add(dto)`、`getAll()`、`remove(localId)`、`count()`

## 6. SyncService

- [x] 6.1 在 `lib/core/services/sync_service.dart` 建立 `SyncService`，注入 `PendingExpenseRepository` 與 `SupabaseExpenseDataSource`
- [x] 6.2 實作 `flush()`：遍歷所有 pending，呼叫 Supabase RPC，成功後移除，失敗則保留
- [x] 6.3 在 `flush()` 完成後 invalidate `expensesProvider` 相關 Provider
- [x] 6.4 在 `ConnectivityService` 偵測到 `isOnline = true` 時自動觸發 `flush()`
- [x] 6.5 在 App 切換回前景時（`AppLifecycleObserver`）若 isOnline 為 true，觸發 `flush()`

## 7. 修改 ExpenseRepositoryImpl 新增消費邏輯

- [x] 7.1 修改 `addExpense()`：isOnline → 直接呼叫 Supabase RPC；否則存入 PendingExpenseRepository，回傳本地假 Expense（含 localId）

## 8. UI 層：離線 SnackBar 與 pending Badge

- [x] 8.1 修改 `AddExpenseScreen`：離線儲存成功後顯示「已離線儲存，稍後將自動同步」SnackBar（取代原「新增成功」SnackBar）
- [x] 8.2 修改 `AddExpenseScreen`：離線時付款人與分攤成員從 group_members_cache 讀取（透過 Provider）
- [x] 8.3 在 `ExpenseListScreen` AppBar 加入 `pendingSyncBadge`：`pendingCountProvider` > 0 時顯示「待同步 N 筆」Chip

## 9. HomeWidgetService

- [x] 9.1 在 `lib/core/services/home_widget_service.dart` 建立 `HomeWidgetService`，實作 `init()` 與 `updateGroups(List<GroupEntity>)`
- [x] 9.2 在 `groupsProvider` 資料更新時呼叫 `HomeWidgetService().updateGroups(groups)`（可於 Repository 或 Provider ref.listen 觸發）

## 10. AppRouter Deep Link 新增

- [x] 10.1 在 `AppRouter` 新增 deep link 監聽（`app_links`），解析 `com.raycat.okaerisplit://add-expense?groupId=<uuid>`
- [x] 10.2 成功解析後呼叫 `context.push('/groups/<uuid>/add-expense')`

## 11. iOS Widget Extension（Xcode 手動 + Swift 程式碼）

- [x] 11.1 Xcode → File → New → Target → Widget Extension，命名 `OkaeriSplitWidget`
- [x] 11.2 Runner 與 OkaeriSplitWidget 同時加入 App Group `group.com.raycat.okaerisplit`
- [x] 11.3 撰寫 Swift `OkaeriSplitWidget.swift`：從 App Group UserDefaults 讀取 `groups_payload` JSON，解析群組陣列
- [x] 11.4 實作 SwiftUI Widget View（Medium size）：顯示最多 3 個群組列（名稱 + 幣別 + Link 按鈕），空資料時顯示提示
- [x] 11.5 Link 按鈕使用 `Link(destination: URL(string: "com.raycat.okaerisplit://add-expense?groupId=<id>"))` 產生 URL scheme
