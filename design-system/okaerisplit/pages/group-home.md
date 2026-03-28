# Page Override: Group Home Screen（群組首頁）

> 繼承 MASTER.md，以下規則覆蓋或補充。

## 佈局結構
1. SliverAppBar（滾動消失的群組標題）
2. SliverPersistentHeader（欠款摘要，固定）
3. SliverAppBar（消費總額 + 搜尋/篩選工具列，固定）
4. 消費列表（依日期分組）

## 篩選工具列
- 搜尋 icon + 篩選 icon（`Icons.tune`）
- 篩選啟用時：`Badge` 顯示啟用數量（已實作）
- 篩選結果為空：顯示「沒有符合條件的消費」+ `TextButton` 清除篩選

## ExpenseCard 規格
- icon container: 44×44px, radius 12px, `primaryContainer` 背景
- 描述：`bodyLarge`, maxLines 1, ellipsis
- 付款人・日期：`bodySmall`, `onSurfaceVariant`
- 金額：`titleSmall`, w700, 靠右
- 待同步 badge：`labelSmall`, `primary` 色

## 日期分組 Header
- 日期：`bodySmall`, w600, `onSurfaceVariant`
- 當日小計：`bodySmall`, w500, 靠右

## FAB
- 右下固定，`+` icon
- 封存群組時隱藏
- 訪客模式時隱藏
