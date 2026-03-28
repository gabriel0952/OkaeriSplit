# Page Override: Dashboard（總覽）

> 繼承 MASTER.md，以下規則覆蓋或補充。

## 用途
用戶打開 App 的第一眼。目標：**3 秒內看懂自己的整體帳務狀況**。

## 佈局優先級
1. `BalanceSummaryCard` — 最重要，放最頂部
2. 各群組餘額列表
3. 最近消費（可選，空間足夠時顯示）

## BalanceSummaryCard 規格
- 淨額：`headlineMedium` (28sp), w700, semantic color — 視覺最突出
- 應收 / 應付：`titleSmall` (14sp), w600, semantic color — 輔助資訊
- 三欄佈局，淨額欄 flex:2，兩側各 flex:1
- 禁止 `FittedBox` 壓縮淨額數字

## 群組餘額 Row 規格
- 右側顯示該群組的「我的淨餘額」badge（綠 +XXX / 紅 -XXX）
- 點擊進入群組詳情
- 高度 ≥ 56px

## Empty State
- icon: `account_balance_wallet_outlined`
- title: `還沒有群組`
- subtitle: `加入或建立群組開始分帳`
- action: `FilledButton` → 建立群組
