## 1. 資料層：CrossGroupDebtItem 與 Provider

- [x] 1.1 在 `dashboard_provider.dart` 新增 `CrossGroupDebtItem` data class（欄位：groupId, groupName, currency, counterpartUserId, counterpartDisplayName, counterpartAvatarUrl, amount, iOwe）
- [x] 1.2 新增 `crossGroupDebtsProvider`（FutureProvider），聚合所有 active 群組的 `simplifiedDebtsProvider` 結果，過濾出含當前使用者的欠款
- [x] 1.3 確認 `crossGroupDebtsProvider` 過濾掉 `status == 'archived'` 的群組
- [x] 1.4 確認排序邏輯：同一區塊項目依群組 `createdAt` 升序排列

## 2. UI：待辦頁面主體

- [x] 2.1 將 `DashboardScreen` 改為 `ConsumerStatefulWidget`，加入 resume 監聽（RouteAware 或 GoRouter listener）
- [x] 2.2 在頁面 resume 時呼叫 `ref.invalidate(crossGroupDebtsProvider)` 實現自動刷新
- [x] 2.3 實作「你需要付款」區塊（section header + item list），資料來自 `iOwe == true` 的項目
- [x] 2.4 實作「別人欠你」區塊（section header + item list），資料來自 `iOwe == false` 的項目
- [x] 2.5 若某區塊無項目則隱藏該區塊（不顯示空區塊）
- [x] 2.6 區塊 header 小計：單一幣別顯示「共 {currency} {total}」，多幣別顯示「共 N 筆」

## 3. UI：待辦項目 Widget

- [x] 3.1 實作 `_PendingDebtItem` widget：顯示對方頭像（MemberAvatar）、對方顯示名稱、群組名稱、幣別金額、chevron icon
- [x] 3.2 點擊項目導航至 `/groups/:groupId/balances`

## 4. UI：Empty States

- [x] 4.1 實作「無群組」empty state：顯示引導訊息「加入或建立一個群組，開始記帳」，附跳轉至群組 tab 的 CTA 按鈕
- [x] 4.2 實作「帳款全清」empty state：顯示「帳款都清楚了」正向回饋訊息與圖示
- [x] 4.3 確認兩種 empty state 的觸發條件互斥（groups 為空 vs groups 非空但無欠款）

## 5. Navigation Tab 更新

- [x] 5.1 在 `main_shell.dart` 將 Tab 1 的 label 從「總覽」改為「待辦」
- [x] 5.2 將 Tab 1 的 icon 從 `Icons.home_outlined` 改為 `Icons.assignment_outlined`（selected: `Icons.assignment`）

## 6. 清理與驗證

- [x] 6.1 移除 `DashboardScreen` 中對 `overallBalancesProvider`、`recentExpensesProvider`、`BalanceSummaryCard`、`GroupBalanceRow`、`RecentExpenseList` 的引用
- [x] 6.2 確認 `balance_summary_card.dart`、`group_balance_row.dart` 不再被引用（保留檔案，僅確認無引用即可）
- [ ] 6.3 手動測試：開啟待辦頁 → 有欠款時兩區塊正確顯示 → 點擊跳轉 → 結算後返回 → 項目自動消失
- [ ] 6.4 手動測試：所有帳清時顯示「帳款都清楚了」empty state
- [ ] 6.5 手動測試：無群組使用者看到引導 empty state
- [ ] 6.6 手動測試：多幣別群組下區塊 header 顯示「共 N 筆」而非跨幣別加總
