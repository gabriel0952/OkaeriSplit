## Context

OkaeriSplit 目前支援手動輸入費用（含品項拆分模式），也已具備 `image_picker` 拍照/選圖與 Supabase Storage 上傳收據附件的能力，但缺乏從圖片自動擷取結構化消費資料的功能。使用者明確要求以本地端辨識為主，不依賴雲端 API，支援中文、英文、日文收據。

原先以 Google ML Kit Text Recognition v2 + 正則表達式實作，但效果不佳，後改以本地多模態 LLM（flutter_gemma + Gemma3n E2B）取代，由模型直接理解圖片並輸出 JSON。

## Goals / Non-Goals

**Goals:**
- 使用者可拍照或選取收據圖片，本地端 LLM 自動辨識並解析品項、數量、總金額
- 支援中文（繁體）、英文、日文三種語言的收據辨識（自動，無需手動選擇）
- 辨識結果可預覽、編輯後一鍵匯入費用表單（自動填入金額與項目拆分）
- 完全離線可用（模型下載後無需網路連線即可辨識）
- 無 API 費用

**Non-Goals:**
- 不做即時相機掃描（非 live camera stream，而是拍照後辨識）
- 不做發票載具自動歸戶或電子發票 API 串接
- 不做辨識歷史紀錄儲存
- 不做 100% 完美解析 — 辨識結果供使用者確認編輯

## Decisions

### Decision 1: 使用本地多模態 LLM（flutter_gemma + Gemma3n E2B）取代 ML Kit OCR

**選擇**：`flutter_gemma: ^0.12.0`（MediaPipe LLM Inference API 的 Flutter 封裝），搭配 Gemma3n E2B int4 量化模型（約 3.1 GB）

**替代方案評估**：

| 方案 | 評估結果 |
|------|----------|
| Google ML Kit Text Recognition v2 | 已嘗試，OCR 效果不足，RegEx 解析誤判多 |
| Cloud AI Vision API（Claude / GPT-4o） | 高品質，但使用者明確要求本地方案 |
| Qwen3-VL 2B（Q4_K_M，~1.1GB）| 多語系優秀，但所有 Flutter llama.cpp 套件（llama_cpp_dart / fllama / flutter_llama）均不支援 multimodal vision，故排除 |
| FastVLM 0.5B | 體積小，但繁中/日文效果差 |
| **Gemma3n E2B int4（~3.1GB）** | **flutter_gemma 唯一支援 vision + 多語系的實用選項，採用** |

**理由**：
- flutter_gemma 0.12.x 透過 `Message.withImage(text:, imageBytes:, isUser: true)` 直接傳入圖片
- Gemma3n E2B 支援繁中/英/日多語系，無需語言選擇器
- 完全 on-device 執行，離線可用，無 API 費用
- 模型首次使用時下載（~3.1 GB），下載後永久儲存於裝置

**模型資訊**：
- 模型：`gemma-3n-E2B-it-int4.task`
- 下載 URL：`https://huggingface.co/gummybear2555/Gemma-3n-E2B-it-int4/resolve/main/gemma-3n-E2B-it-int4.task`
- HF Token 管理：透過 `--dart-define-from-file=dart_defines.json` 在 build time 注入 `HF_TOKEN`

### Decision 2: LLM JSON 輸出解析策略（取代 RegEx 解析器）

**選擇**：Prompt 要求 LLM 直接輸出純 JSON，`LlmReceiptParser` 做防禦性解析

**Prompt 核心**：
```
Return ONLY valid JSON:
{ "total": <number>, "items": [{"name":"...","amount":<number>,"quantity":<int>}] }
Rules:
- Keep original language (Chinese/English/Japanese), do not translate
- amount = line subtotal (quantity × unit price)
- If no total found, sum items
- Output JSON only, no markdown
```

**解析流程**：
```
flutter_gemma LLM 輸出
  → 去除 markdown code fence (```json...```)
  → 找 { ... } JSON 邊界（容錯 LLM 前綴文字）
  → jsonDecode
  → 防禦性 null/type handling（number-as-string、缺少欄位）
  → 映射為 ScanResultEntity
```

**推論參數**：
- `temperature: 0.1`、`topK: 1`（確保輸出穩定）
- `maxTokens: 512`
- 60 秒 timeout

**理由**：
- LLM 直接理解圖片語意，比 RegEx 更能處理多樣格式
- JSON 結構化輸出可程式化解析，防禦性處理各種邊界情況
- 不再需要維護多語言 RegEx pattern

### Decision 3: 模型下載管理（GemmaModelManager）

**選擇**：新增 `core/services/gemma_model_manager.dart` 作為模型生命週期管理單例

**職責**：
- `isModelDownloaded()` — 呼叫 `FlutterGemma.isModelInstalled()` 檢查是否已下載
- `downloadModel()` — 呼叫 `FlutterGemma.installModel().fromNetwork(url, token:).withProgress(cb).install()`，廣播 `Stream<ModelDownloadState>`
- `getReadyModel()` — 回傳 `FlutterGemma.getActiveModel(maxTokens: 512, supportImage: true)`

**狀態機**（sealed class `ModelDownloadState`）：
```
ModelNotDownloaded → ModelDownloading(progress) → ModelReady
                                                 → ModelDownloadError(message)
```

**FlutterGemma 初始化**：必須在 app 啟動時（`main.dart`）呼叫 `FlutterGemma.initialize()`，`GemmaModelManager` 中其他 API 才能正常運作。

### Decision 4: UI 流程設計（含下載狀態）

**選擇**：在 AddExpenseScreen 金額區域保留「掃描收據」按鈕，移除語言選擇器，新增模型下載提示與進度 UI

**更新後流程**：
1. 使用者點擊「掃描收據」→ 選擇拍照/相簿（底部選單僅保留兩個選項，無語言選擇）
2. 選取圖片後導航至 `ReceiptScanResultScreen`
3. **若模型未下載**：顯示說明卡（約 3.1 GB）+ 「下載並辨識」按鈕
4. **下載中**：顯示 `LinearProgressIndicator` + 百分比文字
5. **辨識中**：Loading 動畫 + 「AI 正在分析收據...」
6. **辨識完成**：顯示品項列表、各項金額、總金額（可編輯）
7. 使用者點擊「匯入」→ 回到 AddExpenseScreen，自動填入：
   - 總金額
   - 說明（「收據掃描」）
   - 切換為「項目拆分」模式，填入各品項
   - 收據圖片加入附件

**ScanStatus 狀態機**：
```dart
enum ScanStatus { idle, modelNotDownloaded, downloading, scanning, success, error }
```

### Decision 5: Feature 層架構

遵循 Clean Architecture，在 `features/expenses/` 下新增 receipt scanning 子模組：

```
features/expenses/
├── data/datasources/
│   └── receipt_scan_datasource.dart       # flutter_gemma 推論呼叫 + 圖片預處理
├── data/repositories/
│   └── receipt_scan_repository_impl.dart  # Repository 實作
├── domain/entities/
│   └── scan_result_entity.dart            # 辨識結果 entity
├── domain/repositories/
│   └── receipt_scan_repository.dart       # 抽象介面
├── domain/usecases/
│   └── scan_receipt.dart                  # 掃描收據 use case
├── domain/utils/
│   └── receipt_parser.dart                # LlmReceiptParser（JSON 解析）
└── presentation/
    ├── providers/
    │   └── receipt_scan_provider.dart      # Riverpod provider（含下載狀態）
    └── screens/
        └── receipt_scan_result_screen.dart # 結果編輯頁（含下載/進度 UI）
```

新增 core 層：
```
core/
├── services/
│   └── gemma_model_manager.dart           # 模型生命週期管理（單例）
└── providers/
    └── gemma_model_provider.dart           # gemmaModelManagerProvider
```

### Decision 6: 圖片預處理

**選擇**：使用 `image` package 在推論前對圖片做預處理，防止 OOM 並改善辨識品質

**預處理步驟**：
1. 用 `image` package decode 圖片
2. `bakeOrientation()` 校正 EXIF 旋轉（相機拍照常見問題）
3. `copyResize()` 縮放至最長邊 ≤ 1024px
4. `encodeJpg(quality: 85)` 輸出為 JPEG bytes

### Decision 7: 平台設定

**iOS**：
- Podfile `platform :ios, '16.0'`（flutter_gemma 最低要求）
- `use_frameworks! :linkage => :static`（MediaPipe xcframeworks 靜態連結需求）
- `post_install` 統一設定 `IPHONEOS_DEPLOYMENT_TARGET = '16.0'`
- `EXCLUDED_ARCHS[sdk=iphonesimulator*] = 'arm64'`（解決 TFLite pod 衝突）

**Android**：
- 新增 `proguard-rules.pro` 保留 MediaPipe / Protobuf 類別（防止 release build 混淆）
- `build.gradle.kts` release buildType 加入 proguardFiles 設定

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 模型下載體積大（~3.1 GB），使用者可能拒絕或在弱網路下失敗 | 下載前顯示明確大小說明；下載失敗顯示錯誤訊息，可重試 |
| LLM 推論速度慢（依裝置效能，可能需 10-30 秒） | 60 秒 timeout；辨識中顯示明確 loading；結果僅供使用者確認編輯 |
| LLM 輸出可能不符合 JSON 格式 | 防禦性 `LlmReceiptParser`：去除 code fence、容錯前綴文字、null-safe 欄位映射、malformed JSON 回傳空 items |
| 模型推論記憶體消耗 | 每次推論後呼叫 `model.close()`；`getReadyModel()` 呼叫者負責關閉 |
| iOS Simulator 不支援 GPU inference | Gemma3n 需要實體裝置（iOS 16.0+）；Simulator 無法測試 |
| 圖片大小/旋轉問題 | 推論前統一預處理（縮放至 ≤1024px + EXIF 旋轉校正） |
