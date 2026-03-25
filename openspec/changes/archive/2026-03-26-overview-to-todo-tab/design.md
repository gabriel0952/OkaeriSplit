## Context

目前 OkaeriSplit 的底部導航 Tab 1「總覽」頁面（`DashboardScreen`）顯示：
1. 跨群組應收/應付/淨額加總卡片（`BalanceSummaryCard`）
2. 各群組帳務列表（`GroupBalanceRow`）
3. 最近消費列表（`RecentExpenseList`）

這些資訊的問題：跨群組加總在多幣別情況下毫無意義；群組列表與消費清單在其他頁面已有重複顯示，造成認知負擔而非減少。

改造目標：將此頁重新定位為「帳款待辦清單」，使用者打開 app 就能看到跨群組目前有哪些帳款需要處理。

## Goals / Non-Goals

**Goals:**
- 提供跨群組的待辦欠款聚合視圖（付款方向 + 收款方向）
- 每筆項目點擊直達對應群組結算頁
- 多幣別情境下正確顯示（不做跨幣別加總）
- 無待辦項目時顯示清楚的 empty state

**Non-Goals:**
- 在此頁直接執行付款結算（保留在群組結算頁）
- 提醒 / 通知功能
- 離線待同步費用顯示
- 跨幣別匯率換算與加總

## Decisions

### D1：資料聚合層級放在 Presentation Provider

**決策**：在 `dashboard_provider.dart` 中新增 `crossGroupDebtsProvider`（FutureProvider），不新增 Repository 或 UseCase 層。

**理由**：跨群組聚合是 UI 層的 projection，底層資料（`simplifiedDebtsProvider(groupId)`）已有清晰的領域層實作。在 Presentation 層聚合不破壞既有 Clean Architecture 分層。

**替代方案**：新增 UseCase → 增加 2–3 個檔案，但業務邏輯實際上只是一個 for-loop，過度工程化。

---

### D2：沿用 SimplifiedDebtEntity，以 Wrapper 攜帶群組資訊

**決策**：新增一個輕量的 `CrossGroupDebtItem` data class（放在 dashboard_provider.dart 內），包裹 SimplifiedDebtEntity 的關鍵欄位加上 `groupId`、`groupName`、`currency`、`iOwe`。

**理由**：`SimplifiedDebtEntity` 缺少群組資訊，但為避免修改共用 domain 實體，包一層最低侵入性。

---

### D3：區塊小計顯示邏輯

**決策**：
- 同一區塊所有項目幣別相同 → 顯示 `共 {currency} {total}`
- 混合幣別 → 顯示 `共 N 筆`

**理由**：避免對使用者呈現毫無意義的跨幣別加總（現有總覽頁的核心問題）。

---

### D4：不刪除現有 Widget 檔案

**決策**：`BalanceSummaryCard`、`GroupBalanceRow`、`group_balance_row.dart` 暫時保留，從 DashboardScreen 移除引用即可。

**理由**：避免不必要的刪除風險，保持最小改動範圍。

### D5：只聚合 active 群組

**決策**：`crossGroupDebtsProvider` 在聚合前 SHALL 過濾掉 `status == 'archived'` 的群組。

**理由**：封存群組代表事件已結束，使用者不應再看到這些欠款出現在待辦清單中造成困惑。

---

### D6：排序依群組建立時間升序

**決策**：同一區塊的項目依所屬群組的 `createdAt` 升序排列。

**理由**：與使用者對群組的熟悉度一致，較早加入的群組通常是較長期的（如合租），放在前面更直覺。不用金額排序，避免每次重新整理後順序跳動。

---

### D7：結算後自動刷新策略

**決策**：使用 `go_router` 的 `routerDelegate.addListener` / `ref.invalidate` 搭配現有的 `realtimeSettlementsProvider`。具體做法：

1. 在 `DashboardScreen` 的 `ConsumerStatefulWidget` 中監聽 route change（透過 `RouteAware` 或 `GoRouter.of(context).routeInformationProvider`）
2. 當頁面重新 resume 時呼叫 `ref.invalidate(crossGroupDebtsProvider)`

**替代方案**：在群組結算頁的付款完成 callback 中 invalidate → 需跨頁耦合，不採用。

---

### D8：兩種 Empty State

**決策**：
- 無群組（`groupsProvider` 回傳空列表）→ 顯示「加入或建立群組」引導，附跳轉群組 tab 的 CTA
- 有群組但無欠款 → 顯示「帳款都清楚了」正向回饋

**理由**：兩種情境使用者需要的資訊和行動方向完全不同，混用同一個 empty state 會造成誤導。

## Risks / Trade-offs

- **多群組效能**：`crossGroupDebtsProvider` 需對每個群組呼叫 `simplifiedDebtsProvider`，若群組數量多（>10）會有多個並發請求。→ 緩解：`simplifiedDebtsProvider` 已有 Riverpod cache，重複 watch 不會重複請求；未來可考慮 Supabase RPC 批次查詢。
- **Resume 刷新時序**：頁面 resume 時 invalidate 可能造成短暫的 loading flash。→ 緩解：保留舊資料（`previousData`）在刷新期間繼續顯示，避免畫面空白。
