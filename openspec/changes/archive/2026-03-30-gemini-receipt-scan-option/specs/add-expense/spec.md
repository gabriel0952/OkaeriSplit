## MODIFIED Requirements

### Requirement: 新增費用頁面提供掃描收據入口
AddExpenseScreen SHALL 保留既有的「掃描收據」按鈕與掃描 bottom sheet，並在既有流程中擴充雙方案掃描能力，而不是新增另一個獨立入口。

#### Scenario: 點擊掃描收據按鈕
- **WHEN** 使用者點擊「掃描收據」按鈕
- **THEN** 系統沿用既有的底部彈出選單，並在原本已有的語言提示與影像來源選擇之外，新增掃描方案選擇（本地 OCR / Gemini）

#### Scenario: 未設定 key 時選擇 Gemini
- **WHEN** 使用者在掃描入口選擇 Gemini，但尚未設定 Gemini API key
- **THEN** 系統不進入掃描結果頁，並引導使用者前往個人設定完成 API key 設定

### Requirement: 掃描入口須遵循既有 feature gate
AddExpenseScreen SHALL 以方法級可用性決定掃描入口與選項內容：本地 OCR option 仍受既有可用性檢查控制，Gemini option 則由設定狀態與網路條件控制。

#### Scenario: 本地 OCR 不可用但 Gemini 可使用
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `false`，但使用者已設定 Gemini API key
- **THEN** AddExpenseScreen 仍顯示「掃描收據」入口，且入口中的本地 OCR option 不可選或不顯示，Gemini option 仍可使用

#### Scenario: 本地 OCR 可用但 Gemini 未設定
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `true`，且使用者尚未設定 Gemini API key
- **THEN** AddExpenseScreen 顯示「掃描收據」入口，且本地 OCR option 可使用、Gemini option 顯示需先設定 API key

#### Scenario: 沿用既有語言與圖片來源流程
- **WHEN** 使用者在既有掃描 bottom sheet 中選擇任一掃描方案
- **THEN** 系統保留原本已有的 OCR 語言提示與拍照/相簿來源選擇流程，只額外加入掃描方案層
