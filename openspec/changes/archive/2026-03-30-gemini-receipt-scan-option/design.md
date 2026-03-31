## Context

目前 receipt scan flow 是單一路徑：`AddExpenseScreen` 開啟掃描入口後，`ReceiptScanResultScreen` 直接透過 `receiptScanProvider -> ScanReceipt -> ReceiptScanRepository -> ReceiptScanDatasource` 執行本地 OCR 與規則式解析。這條路徑已能輸出 `ScanResultEntity`，並支援結果編輯與匯入，但無法讓使用者切換掃描引擎，也沒有管理第三方雲端掃描 API key 的能力。

這次變更是跨 UI、domain、local storage 與 Supabase Edge Function 的橫切需求，且牽涉 secret storage、第三方模型代理與現有 capability 修改，因此需要在實作前先明確定義架構。

## Goals / Non-Goals

**Goals:**
- 在不移除既有本地 OCR 的前提下，新增 Gemini 掃描方案讓使用者自行選擇。
- 讓 Gemini API key 僅保存於裝置本地安全儲存，不同步到後端帳號資料。
- 透過 Supabase Edge Function proxy 統一 Gemini prompt、schema 與錯誤轉換。
- 讓 Gemini 與本地 OCR 最終都能映射成既有 `ScanResultEntity` / 匯入流程。
- 在新增費用與個人設定頁提供清楚的方案選擇、設定入口與風險提示。

**Non-Goals:**
- 不移除或重寫既有本地 OCR / 規則式抽取流程。
- 不建立跨裝置同步的 Gemini API key 管理機制。
- 不在第一版加入掃描歷史、雲端掃描結果快取或完整 raw Gemini response 瀏覽。
- 不把這次變更擴大成通用 AI provider 平台；第一版只支援 Gemini。

## Decisions

### 1. 以 `ReceiptScanMethod` 抽象掃描引擎

在 UI、provider、use case、repository 層加入顯式的掃描方法，例如：

- `local`
- `gemini`

`AddExpenseScreen` 在啟動掃描前先收集 `method + image source + language hint`，`ReceiptScanResultScreen` 與 `receiptScanProvider` 則依 method 執行對應流程。這樣可以避免為每種掃描方案拆出平行畫面與平行狀態樹，也讓重新掃描、錯誤處理與未來擴充 provider 時仍可沿用同一套結果頁。

**Alternative considered:** 為 Gemini 另開一組 screen/provider。  
**Rejected because:** 會複製大量既有結果頁與匯入流程，之後維護兩條 UI 會更重。

### 2. Gemini 走 Supabase Edge Function proxy，而非 Flutter client 直接打 Gemini

新增 `supabase/functions/scan_receipt_gemini/index.ts`。App 在使用者選擇 Gemini 掃描時，從 secure storage 讀取 API key，連同圖片與掃描參數送至 Edge Function；Edge Function 以使用者的 key 呼叫 Gemini multimodal API，再回傳 repo 自己定義的穩定 schema。

這個決策的主要理由：
- prompt、schema 與 model 版本調整不必重新發版 App
- 可以把 Gemini 特有的回應格式與錯誤訊息隔離在 function 端
- 可集中做 timeout、payload size、response validation 與 error normalization
- 與現有專案 already-in-use 的 `supabase.functions.invoke(...)` 模式一致

**Alternative considered:** Flutter client 直接呼叫 Gemini API。  
**Rejected because:** 雖然原型較快，但 prompt / schema / parsing 會綁在 client，後續演進成本較高。

### 3. API key 只存 secure storage；Hive 只存非敏感偏好

App 端新增掃描設定 abstraction：
- secure storage：存 Gemini API key
- Hive `settings`：可存預設掃描方案、是否已看過風險提示等非敏感資料

這和目前 repo 的 storage 慣例一致：輕量偏好用 Hive，但 secret 不應明文存在 Hive。

**Alternative considered:** 直接把 API key 存在 Hive 或 Supabase profile。  
**Rejected because:** Hive 明文風險過高；同步到 profile 會擴大資料責任與資安邊界。

### 3a. 金鑰安全採「平台保護 + 最小暴露面」，不做自訂對稱加密方案

第一版的 key security strategy 定義如下：
- App 端以 OS 提供的安全儲存保存 Gemini API key（iOS Keychain / Android Keystore）
- App UI 不回顯完整 key，只顯示已設定狀態或遮罩後片段
- Gemini API key 不寫入 Hive、Supabase profile、database、analytics 或 crash/error log
- App 每次掃描只在需要時讀取 key，請求完成後不在 app state 中長時間持有
- Edge Function 僅於單次 request 記憶體中使用 key，請求結束後即丟棄
- function 端禁止紀錄完整 request body 與任何包含 key 的 debug log

這裡特別不採用「再加一層自訂加密後存本地資料庫」的方式，因為那會引入另一把 app-managed key 的保管問題；若解密材料也在 App 端，同樣會被攻擊面一併取得，安全收益有限，複雜度卻顯著上升。

**Alternative considered:** 以自訂 AES 等應用層加密後再存 Hive。  
**Rejected because:** 真正困難在於加密金鑰管理；若 app 自己持有解密材料，通常只是把風險往後移，不能取代平台安全儲存。

### 3b. 金鑰必須與登入帳號隔離

Gemini API key 屬於「此裝置上的此使用者設定」，不能因為同一台裝置切換帳號而互相看到或誤用。因此實作上應將 key storage 與目前 authenticated user 關聯，例如以 user id namespacing secure storage key，並在 sign-out / account switch 時清除記憶體中的 active key 參考。

這樣的好處是：
- 同裝置多帳號不會共用同一把 Gemini key
- 不需要把 key 上傳到後端來做帳號綁定
- 仍可維持「只存在本機」的安全邊界

**Alternative considered:** 每台裝置只存一把全域 Gemini key。  
**Rejected because:** 在共用裝置或切換帳號情境下，容易讓另一個帳號誤用前一位使用者的 key。

### 4. 以既有 `ScanResultEntity` 作為雙引擎共用的輸出契約

Gemini path 不引入另一套結果頁模型，而是回傳可映射為：
- `items`
- `total`
- `lowConfidence`
- `rawText`（如可安全提供）
- `extraction`（若 Gemini 回傳結構化欄位）

Edge Function 輸出 schema 會偏向 App domain，而不是直接暴露 Gemini 原始 response。這能把 UI 與 provider 對第三方模型格式的耦合降到最低。

**Alternative considered:** 讓結果頁直接吃 Gemini 專屬 response model。  
**Rejected because:** 會迫使 UI 了解 provider-specific response，削弱既有掃描結果頁的可重用性。

### 4a. Gemini 回應 schema 驗證失敗時必須 fail closed

Edge Function 對 Gemini 回應的處理不能建立在「模型大多時候會乖乖輸出 JSON」的假設上。若上游回傳：
- 缺欄位
- 型別錯誤
- 無法解析的 JSON
- 與預期 schema 衝突

系統必須將其視為受控失敗，回傳固定的 parse/schema error 類型，讓 App 顯示可重試或改用本地 OCR 的提示，而不是把半成品資料直接匯入結果頁。

**Alternative considered:** 盡量容忍不合法輸出並猜測補齊。  
**Rejected because:** 這會把不穩定模型輸出直接轉成使用者可匯入的消費資料，風險過高。

### 5. 掃描入口改為「方法級可用性」而不是整體入口被本地 OCR gate 綁死

既有 spec 將掃描入口與 `FlutterLocalAi().isAvailable()` 綁在一起，但 Gemini 方案的目的之一就是補足本地 OCR 能力不足或不可用的情境。新的 UX 規則是：

- 掃描入口保留在新增費用頁
- 本地 OCR option 仍受既有 feature gate 控制
- Gemini option 由「是否有網路 / 是否已設定 API key」決定能否實際進入掃描
- 若未設定 API key，入口仍可顯示 Gemini option，但要引導使用者前往設定

**Alternative considered:** 仍以本地 OCR gate 控制整個掃描入口。  
**Rejected because:** 這會讓 Gemini 在本地 OCR 不可用的裝置上失去存在意義。

### 6. Edge Function 必須實作 key hygiene 與 redaction

`scan_receipt_gemini` function 除了代理 Gemini request 外，也承擔金鑰暴露面的控制責任：
- 只接受 HTTPS 上的受驗證請求
- 從 request 讀取 key 後僅用於單次 Gemini 呼叫
- 不將 key 寫入 console、structured log、error payload、database 或 queue
- 回傳給 App 的錯誤只揭露「invalid key / quota exceeded / timeout / upstream failure」等分類，不回傳敏感上游細節
- 若需要 request diagnostics，使用 request id 與 redacted metadata，而非原始 payload

**Alternative considered:** 讓 App 直接處理所有錯誤與 redaction。  
**Rejected because:** App 與 function 兩邊都可能接觸到 key，若沒有統一的 server-side hygiene 規則，較難保證後端代理層不意外留下敏感資訊。

### 6a. Edge Function 必須實作 abuse guardrails

雖然 Gemini 成本主要計在使用者自己的 API key，但 proxy 仍會消耗我們的網路、執行時間與平台資源，因此 function 需要基本 guardrails：
- 限制接受的 mime type 與圖片大小
- 限制單次 request timeout
- 對 authenticated caller 實作基本 rate limit / throttle 策略
- 對重複失敗請求避免無限制重試

這些 guardrails 的目的不是替使用者節費，而是避免 proxy 被濫用、避免冷啟動/長請求拖垮體驗，並讓失敗模式保持可預測。

**Alternative considered:** 完全依賴 Gemini provider 與使用者自己的 key 配額。  
**Rejected because:** 即使上游 provider 會擋，proxy 仍可能先承受大 payload、長時間連線與惡意重試。

### 6b. 必須明確揭露「使用者自備 key 自行計費」

由於 Gemini 請求是使用使用者自己的 API key 發送，費用、配額與封鎖風險都會落在該使用者的帳號上。這個事實需要在設定與首次使用時被清楚揭露，而不是只在錯誤發生後才讓使用者察覺。

至少要提示：
- Gemini usage 會計入使用者自己的 API key 配額 / 費用
- key 無效、配額用盡或帳號受限時，Gemini 掃描不可用
- 使用者可隨時刪除本機保存的 key，回到本地 OCR 路徑

## Implementation Rules

以下規則是後續實作 `gemini-receipt-scan-option` 時必須遵守的安全守則。

### App 端金鑰儲存規則

1. Gemini API key MUST 只存於平台安全儲存（iOS Keychain / Android Keystore）。
2. Gemini API key MUST NOT 寫入 Hive、SharedPreferences、profile、database 或任何可同步資料。
3. 若使用設定 repository abstraction，該 abstraction 必須在介面層就區分「敏感 key」與「非敏感偏好」。
4. 非敏感偏好（例如預設掃描方案、是否已看過風險提示）才可寫入 Hive `settings`。
5. Gemini API key MUST 與目前登入帳號隔離；不同帳號不得讀取或沿用彼此的 key。

### App 端記憶體與 UI 規則

1. App 只在實際發送 Gemini 掃描 request 前讀取 key，完成 request 後不得長時間保留在 provider/state 中。
2. 設定 UI MUST NOT 回顯完整 key；最多只顯示已設定狀態或遮罩後末段。
3. 若使用者更新或刪除 key，畫面中的舊 key 參考必須立即失效。
4. 任何 snackbar、dialog、error text 都不得包含完整 key。

### App 端日誌與診斷規則

1. `debugPrint`、logger、analytics、crash reporting MUST NOT 包含完整 key。
2. 若需要診斷掃描問題，只能記錄去敏資訊，例如：
   - 使用的掃描方案
   - request id
   - 圖片大小 / mime type
   - 狀態碼 / 錯誤分類
3. 若例外訊息可能包含上游 request 資訊，必須先做 redaction 再顯示或記錄。

### Edge Function 規則

1. Function 只可在單次 request 生命週期內使用 Gemini API key。
2. Function MUST NOT 將 key 寫入 console、structured log、database、queue 或 error payload。
3. Function MUST NOT 記錄完整 request body；若要 log，只能記錄 redacted metadata。
4. Function 回傳給 App 的錯誤必須是分類後的安全錯誤，例如 `invalid_key`、`quota_exceeded`、`timeout`、`upstream_failure`。
5. Function 若偵測到上游回應包含敏感內容，不得原樣透傳給 App。
6. Function MUST 驗證 Gemini 回應 schema；schema 驗證失敗時必須 fail closed。
7. Function MUST 對 payload size、timeout 與 caller request rate 設下 guardrails。

### 傳輸與請求規則

1. App 與 Edge Function 間的 Gemini 掃描請求 MUST 經由 HTTPS。
2. Request payload 僅傳遞本次掃描所需的最小資料：圖片、掃描參數、API key。
3. 不建立 API key 的快取、重播、背景佇列持久化機制。
4. 若請求失敗需要重試，必須重新從 secure storage 讀取 key，而不是使用散落在記憶體中的舊參考。
5. 若 request 因 payload limit、timeout 或 rate limit 被拒絕，回傳結果 MUST 使用明確錯誤分類，而非模糊的通用失敗。

### 驗證規則

1. 必須驗證 key 不會落入 Hive 或其他一般設定儲存。
2. 必須驗證設定頁不會顯示完整 key。
3. 必須驗證錯誤訊息與 log 不包含完整 key。
4. 必須驗證 Edge Function 失敗時只回傳去敏錯誤分類。
5. 必須驗證切換帳號後不會讀取到前一個帳號的 Gemini key。
6. 必須驗證 schema invalid、payload too large、timeout 與 rate limit 都有穩定且安全的錯誤行為。

## Risks / Trade-offs

- **[第三方上傳隱私風險]** → 在設定頁與掃描方案選擇 sheet 清楚提示 Gemini 會把圖片傳給第三方模型服務。
- **[Gemini latency / quota / invalid key 導致失敗]** → 將錯誤分類為可理解的 UI 訊息，並保留本地 OCR 作為替代路徑。
- **[Edge Function 增加一層網路 hop]** → 透過集中 schema 與 prompt 管理換取維護性；第一版接受額外延遲。
- **[App / function schema 漂移]** → 以明確 JSON schema 與 mapping test 保護。
- **[key 洩漏風險]** → API key 不寫入資料庫、不進 profile、不存 Hive；function 僅在請求期間使用。
- **[自訂加密設計錯誤導致虛假安全感]** → 不自行設計 app-level encryption；優先依賴 Keychain/Keystore 與 HTTPS。
- **[診斷需求與金鑰保護衝突]** → 只記錄 request id、狀態碼、圖片大小等去敏資訊，不記錄原始 key 或完整 request body。
- **[同裝置帳號切換造成 key 誤用]** → 以帳號隔離的 secure storage key 與 sign-out 時的記憶體清理避免跨帳號污染。
- **[proxy 被大 payload / 高頻請求拖垮]** → 在 function 層加入 payload、timeout 與 rate-limit guardrails。
- **[使用者不知道 Gemini 費用算在自己帳上]** → 在設定與首次使用時清楚揭露自備 key 計費責任。
- **[模型回傳半合法資料造成錯誤匯入]** → schema 驗證失敗時 fail closed，不產生可匯入結果。

## Migration Plan

1. 先新增設定與 scan method abstraction，但保留本地 OCR 為預設方案。
2. 佈署 `scan_receipt_gemini` Edge Function，確認成功回傳穩定 schema。
3. 啟用新增費用頁的雙方案選擇與設定入口。
4. 若 Gemini path 在 production 出現異常，可暫時移除 Gemini option 或在 UI 層禁用，既有本地 OCR 路徑不受影響。

## Open Questions

- Gemini 是否保留與本地 OCR 相同的語言 hint 選擇，或在第一版固定交由 prompt 自動判斷？目前傾向保留，作為弱提示傳給 function。
- 是否要在設定頁提供「測試 API key」動作？目前傾向要，因為能降低第一次使用時的錯誤成本。
- 是否要在安全設計中加入「切到背景後清空記憶中的暫存 key / scan payload 參考」？目前傾向在實作階段以最小持有時間處理，但不額外引入複雜 lifecycle cache。
