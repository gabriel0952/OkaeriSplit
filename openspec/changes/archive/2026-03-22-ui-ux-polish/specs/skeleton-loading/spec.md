## ADDED Requirements

### Requirement: SkeletonBox 基礎元件
系統 SHALL 提供 `SkeletonBox` Widget，以閃爍漸層動畫呈現佔位色塊，供各頁面骨架屏組合使用。`SkeletonBox` 接受 `width`、`height`、`borderRadius` 參數。動畫應使用左至右流動的 shimmer 效果，週期約 1.5 秒，顏色跟隨主題明/暗模式調整。

#### Scenario: 亮色模式顯示骨架屏
- **WHEN** 使用者開啟消費列表，資料尚未載入
- **THEN** 頁面顯示多個 `SkeletonBox` 組成的列表佔位，帶有左至右閃爍漸層動畫

#### Scenario: 暗色模式顯示骨架屏
- **WHEN** 裝置處於暗色模式，使用者開啟任一有骨架屏的頁面
- **THEN** `SkeletonBox` 使用較深的底色與略淺的 shimmer 色，符合暗色主題

---

### Requirement: 消費列表骨架屏
消費列表載入中時，SHALL 顯示 `ExpenseListSkeleton`：5 個仿 `ExpenseCard` 形狀的骨架行，每行含圓角方形圖示佔位 (44×44)、兩行文字佔位、右側金額佔位。

#### Scenario: 消費列表載入中
- **WHEN** `expensesProvider` 處於 loading 狀態
- **THEN** 顯示 `ExpenseListSkeleton` 取代 `AppLoadingWidget`

---

### Requirement: 群組列表骨架屏
群組列表載入中時，SHALL 顯示 `GroupListSkeleton`：3 個仿 `GroupCard` 形狀的骨架卡片。

#### Scenario: 群組列表載入中
- **WHEN** `groupsProvider` 處於 loading 狀態
- **THEN** 顯示 `GroupListSkeleton` 取代 `AppLoadingWidget`

---

### Requirement: 餘額頁骨架屏
餘額頁載入中時，SHALL 顯示 `BalanceSkeleton`：2 個仿債務行的骨架行 + 頂部摘要卡佔位。

#### Scenario: 餘額頁載入中
- **WHEN** `balancesProvider` 處於 loading 狀態
- **THEN** 顯示 `BalanceSkeleton` 取代 `AppLoadingWidget`
