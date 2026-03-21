## Context

目前 `/groups/:groupId` 路由對應 `GroupDetailScreen`，顯示群組資訊、成員列表，並提供導航至消費紀錄、結算、統計的入口卡片。使用者必須點擊「消費紀錄」入口才能看到消費清單。

消費紀錄才是使用者進入群組後最常操作的核心功能，目前的設計讓核心功能被埋在一層導航之下，增加操作摩擦。

## Goals / Non-Goals

**Goals:**
- 讓 `/groups/:groupId` 直接呈現消費紀錄（`ExpenseListScreen` 的邏輯）
- 在消費紀錄頁頂部顯示群組名稱與結算摘要（誰欠誰多少）
- 新建群組設定頁（`/groups/:groupId/settings`），整合成員管理與群組管理功能
- 保持現有功能完整性（離線支援、realtime 訂閱、Guest 模式限制）

**Non-Goals:**
- 重新設計消費紀錄頁的搜尋/篩選 UI
- 重新設計新增消費流程
- 新增成員管理的新功能（只是搬移入口）
- 修改後端 API 或 Provider 邏輯

## Decisions

### 決策 1：保留 `ExpenseListScreen`，由路由決定入口

**選項 A（採用）**：`/groups/:groupId` 路由直接對應調整後的 `ExpenseListScreen`（或重命名為 `GroupHomeScreen`），在其 AppBar 加入群組摘要與設定入口。
**選項 B**：保留 `GroupDetailScreen` 作為主頁，把消費紀錄提升至最上方顯示。

採用選項 A，因為消費紀錄邏輯已完整實作在 `ExpenseListScreen`，改造現有頁面比在詳情頁內嵌清單更乾淨，也避免 Widget 層級過深。

### 決策 2：群組摘要顯示於 AppBar 下方的 SliverAppBar 或固定 Header

**選項 A（採用）**：在 AppBar 正下方加一個固定高度的摘要 Banner（顯示群組名稱和最多 2 筆結算資訊），滾動時不跟隨消失。
**選項 B**：使用 SliverAppBar 展開/折疊效果。

採用選項 A，因為結算資訊是使用者每次進入都需要快速查看的資料，固定顯示比折疊後需要展開更直覺。

### 決策 3：新建 `GroupSettingsScreen` 而非複用 `GroupDetailScreen`

原 `GroupDetailScreen` 的功能拆分為：
- **頂部摘要**（群組名稱、結算概況）→ 移至新主頁 Header
- **成員管理**（邀請、移除）→ 移至 `GroupSettingsScreen`
- **群組資訊編輯**（名稱、描述）→ 移至 `GroupSettingsScreen`
- **結算/統計入口** → 保留於設定頁，或於主頁 AppBar 提供 overflow menu

`GroupDetailScreen` 功能拆解完後可廢除或僅保留作設定頁基礎。

### 決策 4：路由結構

```
/groups/:groupId                → GroupHomeScreen（消費紀錄 + 摘要）
/groups/:groupId/settings       → GroupSettingsScreen（群組設定 + 成員管理）
/groups/:groupId/add-expense    → AddExpenseScreen（不變）
/groups/:groupId/expenses/:id   → ExpenseDetailScreen（不變）
/groups/:groupId/balances       → BalanceScreen（不變，可從設定頁導入）
/groups/:groupId/settlements    → SettlementHistoryScreen（不變）
/groups/:groupId/stats          → ExpenseStatsScreen（不變，可從設定頁導入）
```

## Risks / Trade-offs

- **[風險] Guest 模式限制**：原 `GroupDetailScreen` 有 `PopScope(canPop: !isGuest)` 防止 Guest 返回。新主頁需繼承相同邏輯。→ 在 `GroupHomeScreen` 保留相同 `PopScope` 包裝。

- **[風險] Deep Link 路徑**：iOS Widget 的 deep link 若有指向 `/groups/:groupId` 以外的路徑需確認不受影響。→ 路由結構僅新增路徑，未移除舊路徑，deep link 相容。

- **[風險] Realtime 訂閱**：原詳情頁有 `realtimeGroupMembersProvider` 訂閱。新主頁改為消費紀錄為主，需確保 `realtimeExpensesProvider` 正確訂閱，成員 realtime 可移至設定頁初始化。→ 兩個訂閱分別在對應頁面 `ref.listen` 即可。

- **[Trade-off] 結算/統計入口位置**：這兩個功能從「群組詳情導航卡」移至「設定頁」，使用者需多一步操作才能到達。→ 可在主頁 AppBar overflow menu 提供快捷入口，降低影響。
