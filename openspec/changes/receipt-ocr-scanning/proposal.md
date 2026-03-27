## Why

使用者在記錄消費時需要手動輸入品項、金額等資訊，流程繁瑣且容易出錯。透過收據/發票拍照辨識功能，使用者只需拍照或從相簿選取單據圖片，系統即可自動辨識並擷取品項名稱、數量與總金額，大幅簡化建帳流程，提升使用體驗。

原先採用 Google ML Kit Text Recognition v2 做 OCR + 正則表達式解析，但實際測試後辨識效果明顯不足（受收據格式多樣、圖片品質影響）。後改採本地端多模態 LLM（flutter_gemma + Gemma3n E2B），但在多數裝置上因模型體積（~3.1GB）造成記憶體不足（OOM）而無法執行。最終採用**系統內建 AI LLM**（iOS Apple Foundation Models / Android ML Kit GenAI）搭配原生 OCR 的兩段式方案。

## What Changes

- **兩段式辨識流程**：先以 Google ML Kit Text Recognition 從收據圖片擷取文字，再將 OCR 文字送入系統內建 LLM（iOS: Apple Foundation Models / Android: ML Kit GenAI）進行語意理解，輸出結構化 JSON
- **使用系統內建 LLM**：完全不需下載模型，iOS 18.1+（Apple Intelligence 裝置）與 Android 支援 AICore 的裝置均可使用
- **不支援裝置降級處理**：在不支援的裝置上隱藏掃描入口或顯示「裝置不支援」提示
- **支援多語言辨識（無需選擇）**：OCR + LLM 自動支援繁中、英文、日文
- **新增收據掃描 UI 流程**：在新增費用頁面加入「掃描收據」入口，提供拍照/選圖 → 辨識中 → 結果預覽/編輯 → 確認匯入的完整流程（移除下載相關 UI）
- **自動填入費用表單**：辨識結果可一鍵匯入至費用表單，自動填入總金額、說明文字，並以「項目拆分」模式填入各品項
- **辨識結果編輯**：使用者可在匯入前修正辨識結果（新增/刪除/修改品項、調整金額）

## Capabilities

### New Capabilities
- `receipt-scanning`: 收據圖片辨識核心能力 — 包含 OCR 文字擷取、系統 LLM 語意理解與結構化、結果預覽編輯、匯入費用表單、不支援裝置提示

### Modified Capabilities
- `add-expense`: 新增費用流程新增「掃描收據」入口按鈕（移除語言選擇），支援從辨識結果自動填入表單欄位（金額、說明、項目拆分）

## Impact

- **新增依賴**：`flutter_local_ai: ^0.0.6`（系統 LLM 封裝）、`google_mlkit_text_recognition: ^0.13.0`（OCR）、`image: ^4.2.0`（圖片預處理）、`path_provider: ^2.1.4`
- **移除依賴**：`flutter_gemma`、`llamafu`
- **後端**：無需後端變更，所有辨識皆在本地完成
- **費用**：無 API 費用，完全免費（on-device processing）
- **模型大小**：無需下載模型，使用系統內建 LLM
- **平台要求**：
  - iOS：功能需 iOS 18.1+（Apple Intelligence，A17 Pro 晶片以上）；app 最低版本維持 iOS 16.0，不支援裝置隱藏入口
  - Android：需要 Android AICore（Pixel 8+、Samsung Galaxy S24+ 等旗艦機）；不支援裝置隱藏入口
- **現有程式碼影響**：
  - `add_expense_screen.dart` — 新增可用性檢查，不支援裝置隱藏掃描按鈕
  - `features/expenses/` — 完整 receipt scanning data/domain/presentation 層（重寫）
  - `core/services/gemma_model_manager.dart` — 大幅簡化（移除下載邏輯，改用 flutter_local_ai）
  - `pubspec.yaml` — 移除 flutter_gemma/llamafu，新增 flutter_local_ai、google_mlkit_text_recognition
