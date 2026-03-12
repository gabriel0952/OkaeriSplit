## Why

新增消費紀錄頁面（`add_expense_screen.dart`）在不同螢幕尺寸的裝置上會出現排版跑版問題，尤其是 `Row` 內欄位（金額 + 幣別、付款人 + 日期）在小螢幕上容易溢出或比例失當，影響使用者填寫體驗。

## What Changes

- 將所有 `Row` 中使用固定比例 `Expanded`/`Flexible` 的欄位改為使用響應式間距與最小寬度限制
- 對金額欄、幣別選單、付款人欄、日期欄使用 `ConstrainedBox` 或 `IntrinsicWidth` 防止溢出
- 表單整體 padding 改為根據螢幕寬度自適應（小螢幕 12px、一般 16px、大螢幕 24px）
- 分帳方式選擇的 `Wrap` 加入 `runSpacing` 與 `spacing` 確保小螢幕換行正常
- 分帳成員列表確保在不同高度裝置上不會被鍵盤遮擋（`resizeToAvoidBottomInset` + `MediaQuery` padding）
- 提交按鈕固定於底部 SafeArea，避免被系統列遮蔽

## Capabilities

### New Capabilities

- `responsive-expense-form`: 新增消費表單的響應式排版能力，確保在 iOS/Android 各種螢幕尺寸（320px～428px 寬）與方向下正確顯示

### Modified Capabilities

（無既有 spec 需修改）

## Impact

- 影響檔案：`app/lib/features/expenses/presentation/screens/add_expense_screen.dart`
- 可能影響：`app/lib/features/expenses/presentation/widgets/category_picker.dart`（若分類選擇器有類似跑版問題）
- 無 API 或資料層變動
- 無 breaking change
