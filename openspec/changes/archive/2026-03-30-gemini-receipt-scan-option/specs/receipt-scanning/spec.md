## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: 掃描流程須支援使用者選擇掃描方案
`receipt-scanning` capability SHALL 將掃描方案視為顯式輸入，並在整個掃描流程中保留使用者所選的掃描方法。

#### Scenario: 保留所選掃描方案
- **WHEN** 使用者從新增費用頁選擇本地 OCR 或 Gemini 掃描後進入結果頁
- **THEN** 結果頁的首次掃描與重新掃描都應沿用該掃描方案

#### Scenario: 切換掃描方案
- **WHEN** 使用者返回掃描入口並重新選擇另一種掃描方案
- **THEN** 後續掃描應改用新方案，而不沿用前一次的 provider

### Requirement: Gemini 掃描須透過 Edge Function 代理
系統 SHALL 透過受控的 Supabase Edge Function 呼叫 Gemini multimodal API，而 SHALL NOT 讓 Flutter client 直接與 Gemini provider 耦合。

#### Scenario: Gemini 掃描成功
- **WHEN** 使用者已設定有效的 Gemini API key，且 Edge Function 成功取得模型結果
- **THEN** 系統回傳經過 schema 驗證與 normalization 的掃描結果給 App

#### Scenario: Gemini API key 無效
- **WHEN** Edge Function 使用使用者提供的 API key 呼叫 Gemini 時收到授權失敗
- **THEN** 系統回傳可識別的錯誤類型，讓 App 提示使用者更新 API key

### Requirement: Gemini 掃描代理不得持久化或外洩使用者金鑰
系統 SHALL 將 Gemini API key 視為單次請求的敏感輸入；Edge Function 不得將其持久化到資料庫、日誌、分析資料或錯誤回應中。

#### Scenario: Edge Function 成功代理請求
- **WHEN** Edge Function 使用使用者提供的 API key 完成一次 Gemini 掃描
- **THEN** 請求完成後系統不保存該 key，且後續資料中不含可還原的完整 key

#### Scenario: Edge Function 代理失敗
- **WHEN** Edge Function 在呼叫 Gemini 或解析回應時失敗
- **THEN** 系統回傳去敏後的錯誤分類，而不在錯誤內容中包含完整 API key 或上游敏感 payload

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

### Requirement: Gemini 掃描須要求網路與本地金鑰
系統 SHALL 只在裝置有網路且本地已設定 Gemini API key 時執行 Gemini 掃描。

#### Scenario: 未設定 Gemini API key
- **WHEN** 使用者選擇 Gemini 掃描，但本地尚未設定 API key
- **THEN** 系統不開始掃描，並引導使用者前往設定 Gemini API key

#### Scenario: 離線時選擇 Gemini 掃描
- **WHEN** 使用者在無網路狀態下選擇 Gemini 掃描
- **THEN** 系統不開始掃描，並提示 Gemini 掃描需要網路連線

### Requirement: Gemini 掃描結果須映射到既有可編輯輸出
系統 SHALL 將 Gemini 回傳結果映射為與本地 OCR 相容的可編輯輸出，使結果頁與匯入流程可重用既有 UI。

#### Scenario: Gemini 回傳結構化品項
- **WHEN** Gemini 成功回傳品項列表、總金額或其他欄位
- **THEN** 系統將結果映射為 `ScanResultEntity` 與結果頁可編輯資料，而不要求結果頁理解 Gemini 原始回應

#### Scenario: Gemini 回傳低信心結果
- **WHEN** Gemini 回傳的欄位或整體結果可信度不足
- **THEN** 系統仍可產生可編輯結果，但須正確映射為 `lowConfidence` 或對應欄位風險資訊

### Requirement: Gemini 回應 schema 無效時系統須安全失敗
系統 SHALL 驗證 Gemini 回應是否符合預期 schema；若 schema 無效或無法解析，系統 SHALL NOT 產生可匯入的半成品結果。

#### Scenario: 回應缺欄位或型別錯誤
- **WHEN** Edge Function 收到 Gemini 回應，但其缺少必要欄位或欄位型別不符預期
- **THEN** 系統回傳明確的 schema/parse 錯誤分類，並要求使用者重試或改用其他掃描方案

#### Scenario: 回應不是可解析的結構化輸出
- **WHEN** Gemini 回傳內容無法被解析為預期的結構化結果
- **THEN** 系統不顯示可編輯掃描結果，並向使用者顯示安全失敗的錯誤提示
