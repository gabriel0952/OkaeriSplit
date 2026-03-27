## Why

新增消費頁面（AddExpenseScreen）已完成視覺翻新：分區 Card 佈局、固定底部提交按鈕、清晰的 section 標籤。但「建立群組」與「消費紀錄篩選」這兩個表單介面仍沿用舊的平鋪欄位設計，整體 App 視覺一致性不足。

## What Changes

- **建立群組頁面**：從平鋪 `Column` 欄位改為分區 Card 佈局（群組基本資訊 card、群組類型 card、幣別 card），Submit 按鈕改為固定於底部的 `FilledButton`，並加入 section 標籤
- **消費紀錄篩選區塊**：`_FilterSection` 從 container 背景底色設計，改為 Card 包裹的分組佈局，關鍵字搜尋、分類篩選、付款人與日期範圍各自清楚分區

## Capabilities

### New Capabilities

- `create-group-form-redesign`: 建立群組頁面套用與 AddExpenseScreen 一致的分區 Card 表單設計
- `expense-filter-redesign`: 消費紀錄篩選區塊套用 Card 分區設計，提升視覺層次

### Modified Capabilities

（無現有 spec 需要修改）

## Impact

- `app/lib/features/groups/presentation/screens/create_group_screen.dart`
- `app/lib/features/expenses/presentation/screens/expense_list_screen.dart`（`_FilterSection` widget）
- 不影響業務邏輯、資料流、路由
