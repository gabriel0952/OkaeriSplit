## Purpose
定義收據掃描 capability，讓使用者可從收據圖片取得可編輯的費用草稿，並在掃描流程中保留結構化抽取、confidence 與回歸評估所需能力。

## Requirements

### Requirement: 使用者可從收據圖片建立可編輯的費用草稿
系統 SHALL 允許使用者拍照或從相簿選取收據/發票圖片，並在掃描前選擇要使用本地 OCR 或 Gemini 掃描。系統完成辨識後 SHALL 產生可編輯的費用草稿供使用者確認與匯入。

#### Scenario: 使用本地 OCR 掃描收據
- **WHEN** 使用者在新增費用頁點擊「掃描收據」，選擇本地 OCR 並完成拍照或相簿選圖
- **THEN** 系統使用既有裝置端 OCR 與解析流程，並於成功後顯示可編輯結果

#### Scenario: 使用 Gemini 掃描收據
- **WHEN** 使用者在新增費用頁點擊「掃描收據」，選擇 Gemini 掃描並完成拍照或相簿選圖
- **THEN** 系統透過 Gemini 掃描流程取得結構化結果，並於成功後顯示可編輯結果

#### Scenario: 辨識成功
- **WHEN** 任一掃描方案成功擷取至少一個品項或總金額
- **THEN** 系統進入辨識結果編輯頁，顯示解析出的品項列表（名稱、數量、金額）與總金額

#### Scenario: 辨識失敗或無法解析
- **WHEN** 所選掃描方案無法擷取文字或無法解析任何有效品項與金額
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

---

### Requirement: 收據掃描流程必須保留可供結構化抽取使用的 OCR 幾何資訊
`receipt-scanning` capability SHALL 在 OCR 流程中保留 block / line / word 與 bounding box 等資訊，供後續建立 receipt document model 使用。

#### Scenario: OCR 結果不再只輸出純文字
- **WHEN** 系統完成 OCR 候選收集
- **THEN** 內部流程應能取得不只純文字的幾何與結構資訊，而不是僅保留最終文字串

#### Scenario: 結構化資訊可轉回現有掃描結果頁
- **WHEN** 系統已完成 layout-aware 抽取
- **THEN** 仍應能將結果轉換為目前掃描結果頁可使用的資料格式

---

### Requirement: 收據掃描流程必須先做 field extraction，再輸出可編輯結果
`receipt-scanning` capability SHALL 先從 receipt document model 抽取固定欄位與 line items，再生成結果頁所需的可編輯資料。

#### Scenario: 抽取 merchant 與金額欄位
- **WHEN** 系統完成 layout-aware field extraction
- **THEN** 掃描流程應能輸出 `merchant`、`subtotal`、`tax` 與 `total` 的抽取結果

#### Scenario: 抽取 line items 並映射到結果頁
- **WHEN** 系統抽取出 line items
- **THEN** 掃描流程應將 line items 映射為結果頁可編輯的品項資料，而不是只依賴逐列文字 pairing

---

### Requirement: 收據掃描流程必須以欄位級與 item 級 confidence 驅動結果提示
`receipt-scanning` capability SHALL 以欄位級與 item 級 confidence 聚合結果提示，而不是只依賴單一整體 `lowConfidence` 判斷。

#### Scenario: 個別欄位低信心
- **WHEN** `merchant`、`total` 或某筆 line item 的 confidence 偏低
- **THEN** 系統應能在內部識別該欄位/品項為高風險結果

#### Scenario: 整體 lowConfidence 由細部 confidence 聚合
- **WHEN** 系統需要決定是否顯示整體低信心提示
- **THEN** `lowConfidence` 應可由欄位級與 item 級 confidence 加總或聚合得出

---

### Requirement: 收據掃描流程必須支援固定樣本集回歸評估
`receipt-scanning` capability SHALL 能以固定樣本集與明確指標驗證流程調整前後的效果。

#### Scenario: 比較 item name 命中
- **WHEN** 團隊修改 layout reconstruction、field extraction 或 heuristics
- **THEN** 團隊必須能比較固定樣本集中 item name 的命中表現

#### Scenario: 比較 amount 與 total 命中
- **WHEN** 團隊修改 layout reconstruction、field extraction 或 heuristics
- **THEN** 團隊必須能比較固定樣本集中 amount 與 total 的命中表現

---

### Requirement: heuristics 補強必須晚於 layout、field extraction、confidence 與 evaluation
`receipt-scanning` capability SHALL 將 pairing、欄位規則與特定版型補強放在 layout understanding、field extraction、confidence 與 evaluation 基礎建立之後。

#### Scenario: 規劃特定版型補強
- **WHEN** 團隊準備新增針對特定店家或版型的 heuristics
- **THEN** 該補強應建立在既有 layout model、欄位抽取與 confidence 機制之上

#### Scenario: 尚未建立評估基準時避免優先新增 heuristics
- **WHEN** 團隊尚未建立固定樣本集與核心命中指標
- **THEN** 不應將零散 heuristics 視為主要優先項目

---

### Requirement: 掃描流程須支援使用者選擇掃描方案
`receipt-scanning` capability SHALL 將掃描方案視為顯式輸入，並在整個掃描流程中保留使用者所選的掃描方法。

#### Scenario: 保留所選掃描方案
- **WHEN** 使用者從新增費用頁選擇本地 OCR 或 Gemini 掃描後進入結果頁
- **THEN** 結果頁的首次掃描與重新掃描都應沿用該掃描方案

#### Scenario: 切換掃描方案
- **WHEN** 使用者返回掃描入口並重新選擇另一種掃描方案
- **THEN** 後續掃描應改用新方案，而不沿用前一次的 provider

---

### Requirement: Gemini 掃描須透過 Edge Function 代理
系統 SHALL 透過受控的 Supabase Edge Function 呼叫 Gemini multimodal API，而 SHALL NOT 讓 Flutter client 直接與 Gemini provider 耦合。

#### Scenario: Gemini 掃描成功
- **WHEN** 使用者已設定有效的 Gemini API key，且 Edge Function 成功取得模型結果
- **THEN** 系統回傳經過 schema 驗證與 normalization 的掃描結果給 App

#### Scenario: Gemini API key 無效
- **WHEN** Edge Function 使用使用者提供的 API key 呼叫 Gemini 時收到授權失敗
- **THEN** 系統回傳可識別的錯誤類型，讓 App 提示使用者更新 API key

---

### Requirement: Gemini 掃描代理不得持久化或外洩使用者金鑰
系統 SHALL 將 Gemini API key 視為單次請求的敏感輸入；Edge Function 不得將其持久化到資料庫、日誌、分析資料或錯誤回應中。

#### Scenario: Edge Function 成功代理請求
- **WHEN** Edge Function 使用使用者提供的 API key 完成一次 Gemini 掃描
- **THEN** 請求完成後系統不保存該 key，且後續資料中不含可還原的完整 key

#### Scenario: Edge Function 代理失敗
- **WHEN** Edge Function 在呼叫 Gemini 或解析回應時失敗
- **THEN** 系統回傳去敏後的錯誤分類，而不在錯誤內容中包含完整 API key 或上游敏感 payload

---

### Requirement: Gemini 掃描代理須具備濫用防護與執行邊界
系統 SHALL 在 Edge Function 層對 Gemini 掃描請求施加 payload、timeout 與 rate limit guardrails，以避免 proxy 被濫用或被異常請求拖垮。

#### Scenario: 圖片 payload 超過上限
- **WHEN** 使用者送出的 Gemini 掃描圖片超過允許大小或不符合支援的格式
- **THEN** 系統拒絕請求並回傳明確的 payload/format 錯誤，而不進行 Gemini 呼叫

#### Scenario: Gemini 掃描逾時
- **WHEN** Edge Function 在預定 timeout 內未取得 Gemini 回應
- **THEN** 系統中止該次代理請求並回傳明確的 timeout 錯誤分類

#### Scenario: 請求頻率超過限制
- **WHEN** 同一 authenticated caller 在短時間內送出過多 Gemini 掃描請求
- **THEN** 系統回傳 rate limit 錯誤分類，並拒絕額外請求直到限制解除

---

### Requirement: Gemini 掃描須要求網路與本地金鑰
系統 SHALL 只在裝置有網路且本地已設定 Gemini API key 時執行 Gemini 掃描。

#### Scenario: 未設定 Gemini API key
- **WHEN** 使用者選擇 Gemini 掃描，但本地尚未設定 API key
- **THEN** 系統不開始掃描，並引導使用者前往設定 Gemini API key

#### Scenario: 離線時選擇 Gemini 掃描
- **WHEN** 使用者在無網路狀態下選擇 Gemini 掃描
- **THEN** 系統不開始掃描，並提示 Gemini 掃描需要網路連線

---

### Requirement: Gemini 掃描結果須映射到既有可編輯輸出
系統 SHALL 將 Gemini 回傳結果映射為與本地 OCR 相容的可編輯輸出，使結果頁與匯入流程可重用既有 UI。

#### Scenario: Gemini 回傳結構化品項
- **WHEN** Gemini 成功回傳品項列表、總金額或其他欄位
- **THEN** 系統將結果映射為 `ScanResultEntity` 與結果頁可編輯資料，而不要求結果頁理解 Gemini 原始回應

#### Scenario: Gemini 回傳低信心結果
- **WHEN** Gemini 回傳的欄位或整體結果可信度不足
- **THEN** 系統仍可產生可編輯結果，但須正確映射為 `lowConfidence` 或對應欄位風險資訊

---

### Requirement: Gemini 回應 schema 無效時系統須安全失敗
系統 SHALL 驗證 Gemini 回應是否符合預期 schema；若 schema 無效或無法解析，系統 SHALL NOT 產生可匯入的半成品結果。

#### Scenario: 回應缺欄位或型別錯誤
- **WHEN** Edge Function 收到 Gemini 回應，但其缺少必要欄位或欄位型別不符預期
- **THEN** 系統回傳明確的 schema/parse 錯誤分類，並要求使用者重試或改用其他掃描方案

#### Scenario: 回應不是可解析的結構化輸出
- **WHEN** Gemini 回傳內容無法被解析為預期的結構化結果
- **THEN** 系統不顯示可編輯掃描結果，並向使用者顯示安全失敗的錯誤提示
