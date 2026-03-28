## ADDED Requirements

### Requirement: 使用者可從收據圖片建立可編輯的費用草稿
系統 SHALL 允許使用者拍照或從相簿選取收據/發票圖片，使用裝置端 OCR 擷取文字，再以規則式解析器推導品項與總金額，並提供可編輯結果供使用者匯入。

#### Scenario: 拍照辨識收據
- **WHEN** 使用者在新增費用頁點擊「掃描收據」並選擇拍照
- **THEN** 系統開啟相機，拍照後進行圖片預處理、OCR 與規則式解析，並顯示辨識中 loading 狀態（「AI 正在分析收據...」）

#### Scenario: 從相簿選取收據圖片
- **WHEN** 使用者在新增費用頁點擊「掃描收據」並選擇從相簿選取
- **THEN** 系統開啟相簿，選取後進行圖片預處理、OCR 與規則式解析

#### Scenario: 辨識成功
- **WHEN** OCR 與解析流程成功擷取至少一個品項或總金額
- **THEN** 系統進入辨識結果編輯頁，顯示解析出的品項列表（名稱、數量、金額）與總金額

#### Scenario: 辨識失敗或無法解析
- **WHEN** OCR 無法擷取文字或解析後無法擷取任何有效品項與金額
- **THEN** 系統顯示錯誤提示，提供重新掃描選項

---

### Requirement: 掃描流程支援 OCR 語言提示
系統 SHALL 在開始辨識前提供 OCR 語言提示選項，預設為自動，並將選項傳入掃描流程。

#### Scenario: 使用預設自動模式
- **WHEN** 使用者打開掃描收據 sheet 且未變更語言
- **THEN** 系統以 `auto` 作為語言提示啟動掃描

#### Scenario: 使用者選擇特定語言
- **WHEN** 使用者在掃描前選擇中文、日文或英文
- **THEN** 系統將該語言提示傳入 OCR 流程，以改善辨識優先順序

---

### Requirement: 系統須使用平台原生 OCR 能力
系統 SHALL 依平台使用既有原生 OCR 整合，而非依賴雲端辨識服務。

#### Scenario: iOS 掃描收據
- **WHEN** 使用者在 iOS 裝置上進行收據掃描
- **THEN** 系統透過 `com.okaeri.native_ocr` method channel 呼叫 `Vision` 完成文字辨識

#### Scenario: Android 掃描收據
- **WHEN** 使用者在 Android 裝置上進行收據掃描
- **THEN** 系統透過 `google_mlkit_text_recognition` 完成文字辨識

#### Scenario: 辨識結果整理為逐列文字
- **WHEN** OCR 回傳多個區塊與行
- **THEN** 系統應依 bounding box 順序重新組成較穩定的逐列文字結果，再交由解析器處理

---

### Requirement: 收據文字須解析為結構化資料
系統 SHALL 以規則式解析器將 OCR 文字轉換為 `ScanResultEntity`，至少包含品項列表、總金額與可信度標記。

#### Scenario: 解析標準格式收據
- **WHEN** OCR 文字包含明確的品項名稱與價格
- **THEN** 解析器擷取各品項的名稱、金額，以及可推導時的數量或單價資訊

#### Scenario: 解析含數量的品項
- **WHEN** OCR 文字中出現同列品項名稱與價格、或可辨識的數量語境
- **THEN** 解析器可為結果填入 `quantity`，並在需要時推導 `unitPrice`

#### Scenario: 解析餐飲點餐單單行格式
- **WHEN** OCR 文字中出現 `品項名稱 單價 x 數量 總價` 或其常見 OCR 誤讀變形（例如 `% / k / K` 被誤當乘號）
- **THEN** 解析器應優先把該行視為單一品項，並推導 `unitPrice`、`quantity` 與 `amount`

#### Scenario: 過濾餐飲點餐單表頭資訊
- **WHEN** OCR 文字包含桌號、人數、點餐員、單號、服務費等非品項資訊
- **THEN** 解析器不應將這些資訊誤判為品項名稱

#### Scenario: 僅辨識到總金額
- **WHEN** 系統無法解析出個別品項，但可辨識 footer total
- **THEN** 結果僅包含總金額，品項列表為空，使用者可手動新增品項

#### Scenario: OCR 文字品質不穩
- **WHEN** 解析器必須使用低可信規則、或總額與品項加總落差過大
- **THEN** 結果仍可產生，但 `lowConfidence` 應標記為 `true`

---

### Requirement: 辨識結果可預覽與編輯
系統 SHALL 提供辨識結果編輯介面，使用者可在匯入費用表單前修正品項資料。

#### Scenario: 編輯品項名稱與金額
- **WHEN** 使用者在辨識結果頁點擊某品項
- **THEN** 該品項的名稱與金額欄位變為可編輯狀態，修改後即時更新總金額

#### Scenario: 刪除品項
- **WHEN** 使用者在辨識結果頁滑動刪除或點擊刪除某品項
- **THEN** 該品項從列表移除，總金額即時更新

#### Scenario: 新增品項
- **WHEN** 使用者在辨識結果頁點擊「新增品項」
- **THEN** 列表底部新增一筆空白品項，使用者可輸入名稱與金額

#### Scenario: 修改總金額
- **WHEN** 使用者手動修改總金額
- **THEN** 系統保留使用者輸入的總金額（不自動以品項金額加總覆蓋）

---

### Requirement: 低信心結果必須明確提示
系統 SHALL 在辨識結果可信度不足時顯示警示，但不應阻止使用者繼續手動修正並匯入。

#### Scenario: 顯示低信心警示
- **WHEN** `ScanResultEntity.lowConfidence` 為 `true`
- **THEN** 結果頁顯示提示，提醒使用者確認品項與金額後再匯入

#### Scenario: 低信心結果仍可匯入
- **WHEN** 使用者已檢查並接受低信心結果
- **THEN** 系統仍允許使用者點擊匯入，將修正後結果帶回費用表單

---

### Requirement: 候選 OCR 結果須優先選擇最適合結構化解析的版本
系統 SHALL 對多個 OCR 候選結果進行評分，並優先選擇品項名稱較完整、名稱/價格配對較穩定的候選，而非單純選擇字數最多的原文。

#### Scenario: 品項名稱較完整的候選勝出
- **WHEN** 多個 OCR 候選都可解析出品項，但其中一個候選的品項名稱較完整、較少雜訊
- **THEN** 系統應選擇該候選作為最終辨識結果

#### Scenario: 名稱與價格配對較穩定的候選勝出
- **WHEN** 某 OCR 候選的文字較長，但品項與價格配對存在更多歧義或 fallback
- **THEN** 系統應優先選擇配對更穩定的候選結果

---

### Requirement: 目前版本須遵循既有功能入口策略
系統 SHALL 延續目前 `AddExpenseScreen` 的 feature gate 行為，僅在可用性檢查通過時顯示掃描入口。

#### Scenario: 可用性檢查未通過
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `false`
- **THEN** `AddExpenseScreen` 不顯示「掃描收據」入口

#### Scenario: 結果頁保留不支援畫面
- **WHEN** 掃描狀態進入 `notSupported`
- **THEN** 系統顯示不支援訊息卡，並提供返回操作
