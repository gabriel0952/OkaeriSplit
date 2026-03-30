## ADDED Requirements

### Requirement: 新增費用頁面提供掃描收據入口
AddExpenseScreen SHALL 在金額輸入區域提供「掃描收據」按鈕，作為收據辨識功能的入口。

#### Scenario: 顯示掃描收據按鈕
- **WHEN** 使用者進入新增費用頁面
- **THEN** 若目前的可用性檢查通過，金額輸入區域旁顯示「掃描收據」按鈕（相機圖示）

#### Scenario: 點擊掃描收據按鈕
- **WHEN** 使用者點擊「掃描收據」按鈕
- **THEN** 系統顯示底部彈出選單，提供 OCR 語言提示選擇（自動 / 中文 / 日文 / 英文）以及「拍照」與「從相簿選取」兩個影像來源選項

---

### Requirement: 掃描入口須遵循既有 feature gate
AddExpenseScreen SHALL 以目前專案中的可用性檢查結果決定是否顯示掃描入口。

#### Scenario: 裝置不顯示掃描入口
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `false`
- **THEN** AddExpenseScreen 不顯示「掃描收據」按鈕

#### Scenario: 裝置顯示掃描入口
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `true`
- **THEN** AddExpenseScreen 顯示「掃描收據」按鈕並允許使用者開始掃描流程

---

### Requirement: 支援從辨識結果自動填入表單
AddExpenseScreen SHALL 接收來自辨識結果頁的資料，自動填入費用表單對應欄位。

#### Scenario: 自動填入金額與說明
- **WHEN** 辨識結果匯入至費用表單
- **THEN** 金額欄位填入辨識的總金額，且僅在說明欄位原本為空時填入「收據掃描」

#### Scenario: 自動切換為項目拆分並填入品項
- **WHEN** 辨識結果包含多個品項且匯入至費用表單
- **THEN** 分攤方式自動切換為「項目拆分」，並以辨識結果覆蓋現有項目列表

#### Scenario: 收據圖片自動加入附件
- **WHEN** 辨識結果匯入至費用表單
- **THEN** 收據原始圖片自動加入附件列表

#### Scenario: 套用結果頁選擇的幣別
- **WHEN** 使用者在掃描結果頁選擇了幣別再匯入
- **THEN** 費用表單應套用該幣別

#### Scenario: 帶回每個品項的成員指派
- **WHEN** 辨識結果中的品項已在結果頁指定分攤成員
- **THEN** 匯入後各 itemized 項目應帶入對應的 `sharedByUserIds`

#### Scenario: 費用表單已有資料時匯入
- **WHEN** 使用者在已填入部分資料的費用表單中執行掃描並匯入
- **THEN** 系統以辨識結果覆蓋金額與品項，但保留使用者既有的付款人與其他未被匯入資料直接覆蓋的表單上下文
