## 1. 掃描方法與設定基礎

- [x] 1.1 定義 `ReceiptScanMethod` 與相關輸入模型，讓掃描流程可顯式傳遞本地 OCR / Gemini 方案
- [x] 1.2 新增 Gemini 掃描設定 abstraction，區分 secure storage 的 API key 與 Hive `settings` 的非敏感偏好
- [x] 1.3 在 `ProfileScreen` 新增 Gemini 掃描設定入口，提供儲存、更新、刪除與已設定狀態顯示
- [x] 1.4 補上 key 安全規則：UI 不回顯完整 key、錯誤訊息與診斷輸出不得包含完整 key
- [x] 1.5 依 design.md 的 Implementation Rules 建立 key handling 守則，確保 App 端 storage、UI、state 與 error handling 都符合規範
- [x] 1.6 讓 Gemini key 與登入帳號隔離，並在 sign-out / account switch 時清除 active key 參考
- [x] 1.7 在設定與首次使用流程加入「使用者自備 key 自行計費」提示

## 2. 掃描入口與結果頁整合

- [x] 2.1 擴充 `AddExpenseScreen` 既有的掃描 sheet，在現有語言與圖片來源流程中加入掃描方案選擇、Gemini 前置提示與未設定 key 的導引
- [x] 2.2 更新 `ReceiptScanResultScreen` 與 `receiptScanProvider`，讓首次掃描與重新掃描都依所選 method 執行
- [x] 2.3 調整掃描入口可用性判斷，讓本地 OCR 與 Gemini 以方法級條件各自控制

## 3. Gemini 掃描後端流程

- [x] 3.1 新增 `supabase/functions/scan_receipt_gemini/index.ts`，驗證 request、限制 payload、使用使用者提供的 API key 呼叫 Gemini
- [x] 3.2 設計 Gemini prompt 與輸出 JSON schema，確保可穩定回傳品項、總金額與低信心資訊
- [x] 3.3 在 Flutter 端新增 Gemini datasource / repository wiring，串接 Edge Function 並處理錯誤分類
- [x] 3.4 在 Edge Function 補上 key hygiene：不得記錄完整 request body / API key，錯誤回應只輸出去敏分類
- [x] 3.5 依 design.md 的 Implementation Rules 檢查 Edge Function 的 request lifecycle、logging 與 retry 行為不會額外暴露 key
- [x] 3.6 為 Gemini proxy 加入 payload 大小、timeout 與 rate limit guardrails
- [x] 3.7 實作 Gemini 回應 schema 驗證與 fail-closed 錯誤處理

## 4. 結果映射與 UX 補強

- [x] 4.1 將 Gemini 回傳結果映射為 `ScanResultEntity` 與既有匯入流程可用的資料格式
- [x] 4.2 補齊 Gemini 專屬錯誤體驗，包括未設定 key、無網路、API key 無效、逾時與第三方上傳提示
- [x] 4.3 確認 Gemini 與本地 OCR 都能維持既有結果頁編輯、低信心提示與匯入表單行為

## 5. 驗證與回歸

- [x] 5.1 為 Gemini 設定儲存與掃描 method wiring 補單元測試
- [x] 5.2 為 Gemini 結果 mapping 與 repository error handling 補最小測試
- [x] 5.3 為 key storage、masked display 與 redacted error handling 補安全相關測試或驗證
- [x] 5.4 執行 Flutter analyze / 現有 receipt scan 相關測試與必要的 Edge Function 驗證，確認不破壞既有本地 OCR 路徑
- [x] 5.5 驗證帳號切換不會共用 Gemini key，且 payload/rate-limit/schema-error 都有明確錯誤行為
