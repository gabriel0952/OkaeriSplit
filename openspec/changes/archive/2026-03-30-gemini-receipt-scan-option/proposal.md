## Why

目前收據掃描只依賴裝置端 OCR 與規則式解析，對複雜版型、低品質圖片與餐飲/零售混合格式的上限仍然明顯。為了讓使用者在保留既有離線、本地掃描體驗的同時，能自行選擇更高品質的雲端辨識方案，本次要新增一條以使用者自備 Gemini API key 為基礎的掃描路徑。

## What Changes

- 擴充新增費用頁既有的掃描收據選單，在目前已有的語言與圖片來源選擇流程中加入「本地 OCR」與「Gemini 掃描」兩種方案選擇。
- 新增使用者自備 Gemini API key 的設定流程，讓使用者可在 App 內設定、更新、刪除並查看已設定狀態。
- 新增透過 Supabase Edge Function 代理的 Gemini 掃描流程，接收圖片、呼叫 Gemini multimodal API，並將結果整理成 App 既有可匯入的掃描資料格式。
- 讓掃描結果頁與掃描 provider 能依掃描方案運作，同時維持既有本地 OCR 路徑與離線可用性。
- 新增 Gemini 專屬錯誤體驗與風險提示，例如未設定 API key、需要網路、API key 無效、回應逾時與第三方上傳提醒。

## Capabilities

### New Capabilities
- `scan-provider-settings`: 管理使用者的掃描方案偏好與 Gemini API key 設定狀態，包含安全儲存、設定入口與風險提示。

### Modified Capabilities
- `receipt-scanning`: 將單一本地 OCR 掃描流程擴充為可選擇本地 OCR 或 Gemini 掃描，並定義 Gemini proxy、輸出映射與錯誤行為。
- `add-expense`: 擴充既有掃描收據按鈕與 bottom sheet，讓使用者在新增費用頁的現有掃描流程中可選掃描方案並承接 Gemini 結果。

## Impact

- Flutter App：`AddExpenseScreen`、`ReceiptScanResultScreen`、`receipt_scan_provider`、scan repository/use case、Profile 設定 UI。
- Supabase：新增 Gemini 掃描用 Edge Function。
- 依賴：預期新增安全儲存套件（例如 `flutter_secure_storage`）以保護 API key。
- 使用者體驗：保留本地 OCR 作為既有預設與離線方案，新增需網路與第三方模型的 Gemini 選項。
