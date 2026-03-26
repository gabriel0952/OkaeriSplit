## Why

使用者在記錄消費時需要手動輸入品項、金額等資訊，流程繁瑣且容易出錯。透過收據/發票拍照辨識功能，使用者只需拍照或從相簿選取單據圖片，系統即可自動辨識並擷取品項名稱、數量與總金額，大幅簡化建帳流程，提升使用體驗。

原先採用 Google ML Kit Text Recognition v2 做 OCR + 正則表達式解析，但實際測試後辨識效果明顯不足（受收據格式多樣、手寫字跡、圖片品質影響），改採本地端多模態 LLM 方案，由模型直接理解收據圖片並輸出結構化 JSON。

## What Changes

- **改用本地多模態 LLM 辨識**：使用 `flutter_gemma`（MediaPipe LLM Inference 封裝）搭配 Gemma3n E2B 模型，圖片直接輸入模型，由 LLM 輸出結構化 JSON，辨識品項、數量、金額
- **支援多語言辨識（無需選擇）**：Gemma3n 自動支援繁中、英文、日文，使用者不需手動選擇語言
- **首次使用下載模型**：Gemma3n E2B 模型約 3.1 GB，首次進入掃描功能時提示使用者下載，下載完成後離線可用
- **新增收據掃描 UI 流程**：在新增費用頁面加入「掃描收據」入口，提供拍照/選圖 → 下載提示/進度 → 辨識中 → 結果預覽/編輯 → 確認匯入的完整流程
- **自動填入費用表單**：辨識結果可一鍵匯入至費用表單，自動填入總金額、說明文字，並以「項目拆分」模式填入各品項
- **辨識結果編輯**：使用者可在匯入前修正辨識結果（新增/刪除/修改品項、調整金額）

## Capabilities

### New Capabilities
- `receipt-scanning`: 收據圖片辨識核心能力 — 包含本地多模態 LLM 辨識、結果預覽編輯、匯入費用表單、模型下載管理

### Modified Capabilities
- `add-expense`: 新增費用流程新增「掃描收據」入口按鈕（移除語言選擇），支援從辨識結果自動填入表單欄位（金額、說明、項目拆分）

## Impact

- **新增依賴**：`flutter_gemma: ^0.12.0`（MediaPipe LLM Inference）、`image: ^4.2.0`（圖片預處理）、`path_provider: ^2.1.4`、`http: ^1.2.2`
- **移除依賴**：`google_mlkit_text_recognition`
- **後端**：無需後端變更，所有辨識皆在本地完成
- **費用**：無 API 費用，完全免費（on-device processing）
- **模型大小**：Gemma3n E2B 約 3.1 GB，首次使用時從 HuggingFace 下載，儲存於裝置本地
- **HuggingFace Token**：需在 build 時透過 `--dart-define-from-file=dart_defines.json` 注入 `HF_TOKEN`
- **平台最低版本**：iOS 需升至 16.0（flutter_gemma 要求）
- **現有程式碼影響**：
  - `add_expense_screen.dart` — 移除語言選擇，簡化掃描入口
  - `features/expenses/` — 完整 receipt scanning data/domain/presentation 層（已實作）
  - `core/services/gemma_model_manager.dart` — 新增模型生命週期管理
  - `pubspec.yaml` — 移除 mlkit，新增 flutter_gemma 等依賴
  - `ios/Podfile` — 升至 iOS 16.0，改用 static linkage
