## ADDED Requirements

### Requirement: 登出時清除所有功能快取 Box
使用者登出時，系統 SHALL 清除所有 Hive 功能快取 box（groups_cache、expenses_cache、group_members_cache），確保下一個帳號登入後不會看到前帳號的殘留資料。

#### Scenario: 登出時快取清除
- **WHEN** 使用者執行登出操作
- **THEN** 系統 SHALL 在 Supabase session 清除後，依序呼叫所有功能快取 box 的 clear()

#### Scenario: 登出後重新登入不顯示舊資料
- **WHEN** 使用者登出後以不同帳號重新登入
- **THEN** 群組列表、消費列表、成員列表 SHALL 顯示新帳號的資料，不出現前帳號資料

---

### Requirement: 登出時重置所有 Riverpod provider state
使用者登出時，系統 SHALL invalidate 所有與資料相關的 Riverpod provider，確保重新登入後資料從後端重新 fetch。

#### Scenario: 登出後 provider 狀態清除
- **WHEN** auth state 變為 signedOut
- **THEN** groupsProvider、expensesProvider、settlementsProvider、balancesProvider 等 SHALL 全部被 invalidate

#### Scenario: 重新登入後資料自動重新載入
- **WHEN** 使用者登出後重新登入
- **THEN** 各畫面 SHALL 自動觸發重新 fetch，不需使用者手動下拉刷新
