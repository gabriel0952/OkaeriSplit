## ADDED Requirements

### Requirement: 建立群組表單採分區 Card 佈局
建立群組頁面 SHALL 將表單欄位分成三個 Card 區塊：群組名稱、群組類型、幣別。每個 Card 之間 SHALL 有 12px 間距，Card 上方 SHALL 顯示 `titleSmall` section 標籤（第一個 Card 除外）。

#### Scenario: 頁面渲染時各 Card 正常顯示
- **WHEN** 使用者開啟建立群組頁面
- **THEN** 畫面 SHALL 顯示：群組名稱 Card（含 TextField）、帶 '群組類型' 標籤的 SegmentedButton Card、帶 '幣別' 標籤的幣別選擇 Card

### Requirement: 建立群組提交按鈕固定於底部
提交按鈕 SHALL 固定於頁面底部（`SafeArea` 包裹），採全寬 `FilledButton`，不隨表單卷動。

#### Scenario: 提交按鈕位置
- **WHEN** 使用者在建立群組頁面向下捲動
- **THEN** 提交按鈕 SHALL 保持固定於螢幕底部可見

#### Scenario: 提交中顯示 loading 狀態
- **WHEN** 使用者點擊提交且請求進行中
- **THEN** 按鈕 SHALL 顯示 `CircularProgressIndicator` 並禁用點擊

### Requirement: 幣別選擇改為 bottom sheet picker
幣別 SHALL 以 Card 內 `ListTile`（顯示目前選擇 + 下拉箭頭 icon）呈現，點擊後 SHALL 開啟 `showModalBottomSheet` 供選擇，與 AddExpenseScreen 的幣別選取一致。

#### Scenario: 點擊幣別列開啟 bottom sheet
- **WHEN** 使用者點擊幣別 ListTile
- **THEN** SHALL 彈出含幣別清單的 bottom sheet

#### Scenario: 選擇幣別後關閉 bottom sheet
- **WHEN** 使用者在 bottom sheet 中選擇某個幣別
- **THEN** bottom sheet SHALL 關閉，ListTile SHALL 更新顯示所選幣別

### Requirement: 錯誤訊息顯示於提交按鈕上方
API 錯誤 SHALL 顯示於底部提交按鈕上方的區域，不再夾雜於表單欄位之間。

#### Scenario: API 錯誤顯示位置
- **WHEN** 建立群組失敗
- **THEN** 錯誤訊息 SHALL 出現在底部按鈕上方，文字顏色為 `colorScheme.error`
