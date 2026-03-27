## Context

OkaeriSplit 目前支援手動輸入費用（含品項拆分模式），也已具備 `image_picker` 拍照/選圖與 Supabase Storage 上傳收據附件的能力，但缺乏從圖片自動擷取結構化消費資料的功能。使用者明確要求以本地端辨識為主，不依賴雲端 API，支援中文、英文、日文收據。

技術選型演進：
1. **Google ML Kit + RegEx**：OCR 效果可，但 RegEx 解析收據格式多樣，誤判多
2. **flutter_gemma + Gemma3n E2B（~3.1GB）**：直接圖片輸入，但模型體積過大，在多數裝置上記憶體不足（OOM）
3. **FastVLM 0.5B**：體積小，但授權僅限學術研究，不可商用
4. **llamafu + Qwen2-VL 2B**：pub.dev 版本缺少 llama.cpp submodule，build 失敗
5. **Apple Foundation Models / Android ML Kit GenAI（最終選擇）**：系統內建 LLM，無需下載模型，無記憶體壓力

## Goals / Non-Goals

**Goals:**
- 使用者可拍照或選取收據圖片，本地端 AI 自動辨識並解析品項、數量、總金額
- 支援中文（繁體）、英文、日文三種語言的收據辨識（自動，無需手動選擇）
- 辨識結果可預覽、編輯後一鍵匯入費用表單（自動填入金額與項目拆分）
- 完全離線可用（無需網路連線即可辨識）
- 無 API 費用，不需下載額外模型
- 不支援裝置優雅降級（隱藏入口或顯示提示）

**Non-Goals:**
- 不做即時相機掃描（非 live camera stream，而是拍照後辨識）
- 不做發票載具自動歸戶或電子發票 API 串接
- 不做辨識歷史紀錄儲存
- 不做 100% 完美解析 — 辨識結果供使用者確認編輯
- 不為不支援裝置提供降級辨識方案（例如雲端 fallback）

## Decisions

### Decision 1: 兩段式辨識（OCR + 系統 LLM）

**選擇**：Google ML Kit Text Recognition 擷取圖片文字 → `flutter_local_ai` 呼叫系統 LLM（iOS: Apple Foundation Models / Android: ML Kit GenAI）結構化輸出 JSON

**替代方案演進與排除原因**：

| 方案 | 排除原因 |
|------|----------|
| Google ML Kit Text Recognition v2 + RegEx | OCR 可行，但 RegEx 解析多格式收據準確度差 |
| Cloud AI Vision API（Claude / GPT-4o） | 使用者要求本地方案，不依賴網路/付費 API |
| flutter_gemma + Gemma3n E2B（~3.1GB） | 模型過大，多數裝置 OOM，無法實際使用 |
| FastVLM 0.5B | 商業授權限制（Apple Research License，僅限學術） |
| llamafu + Qwen2-VL 2B | pub.dev 包未含 llama.cpp submodule，pod install 失敗 |
| **Apple Foundation Models + ML Kit OCR（最終選擇）** | **系統內建，無需下載，無記憶體壓力，多語言支援** |

**流程**：
```
圖片
  → Google ML Kit Text Recognition（OCR 文字擷取）
  → flutter_local_ai（系統 LLM 語意理解）
  → LlmReceiptParser（JSON 解析）
  → ScanResultEntity
```

**理由**：
- 系統 LLM 不需下載額外模型，無記憶體壓力
- ML Kit OCR 對印刷體收據（含 CJK）準確度高
- LLM 做語意理解與結構化，比 RegEx 更能處理多樣格式
- `flutter_local_ai` 提供 `isAvailable()` 可統一處理不支援裝置

### Decision 2: 裝置可用性策略

**選擇**：啟動時呼叫 `FlutterLocalAi().isAvailable()` 判斷，不支援裝置隱藏掃描入口

**支援裝置範圍**：
- iOS 18.1+（Apple Intelligence）：iPhone 15 Pro / Pro Max、iPhone 16 系列以上（A17 Pro 晶片）
- Android AICore：Pixel 8+、Samsung Galaxy S24+ 等旗艦機

**UI 策略**：
- `AddExpenseScreen`：`isAvailable()` 為 false 時隱藏「掃描收據」按鈕（不顯示任何提示）
- `ReceiptScanResultScreen`：進入時再次檢查，若不可用顯示「此裝置不支援 AI 辨識功能」提示

**理由**：不支援裝置直接隱藏按鈕，避免引導使用者進入後才發現無法使用的體驗

### Decision 3: LLM JSON 輸出解析策略

**選擇**：Prompt 要求 LLM 直接輸出純 JSON，`LlmReceiptParser` 做防禦性解析（沿用原有解析器）

**Prompt 核心**：
```
以下是從收據圖片擷取的文字：
[OCR 文字]

請從上述文字擷取消費資訊，以 JSON 格式輸出，不加任何說明：
{ "total": <number>, "items": [{"name":"...","amount":<number>,"quantity":<int>}] }
規則：
- 保留原始語言（中/英/日），不翻譯
- amount = 該行小計（數量 × 單價）
- 若無總金額，自動加總品項
- 僅輸出 JSON，不含 markdown
```

**解析流程**（沿用）：
```
LLM 文字輸出
  → 去除 markdown code fence
  → 找 { ... } JSON 邊界（容錯前綴文字）
  → jsonDecode
  → 防禦性 null/type handling
  → 映射為 ScanResultEntity
```

**理由**：`LlmReceiptParser` 邏輯不變，只是 LLM 來源從 flutter_gemma 換成 flutter_local_ai

### Decision 4: GemmaModelManager 簡化

**選擇**：保留 `GemmaModelManager` 檔案與介面，但大幅簡化——移除下載邏輯，改為封裝 `flutter_local_ai` 可用性檢查與推論呼叫

**新職責**：
- `isModelDownloaded()` → 改名語意更準確，實際呼叫 `FlutterLocalAi().isAvailable()`
- `getReadyModel()` → 回傳 `FlutterLocalAi` 實例（已初始化）
- 移除：`downloadModel()`、`ModelDownloading`、`ModelReady` 等下載相關狀態

**`ScanStatus` 更新**：
```dart
// 移除
enum ScanStatus { idle, modelNotDownloaded, downloading, scanning, success, error }

// 更新為
enum ScanStatus { idle, notSupported, scanning, success, error }
```

**理由**：不再需要模型下載流程，UI 大幅簡化

### Decision 5: UI 流程設計（移除下載流程）

**更新後流程**：
1. `AddExpenseScreen` 啟動時檢查 `isAvailable()`，不支援裝置隱藏按鈕
2. 使用者點擊「掃描收據」→ 選擇拍照/相簿（底部選單僅保留兩個選項）
3. 選取圖片後導航至 `ReceiptScanResultScreen`
4. **辨識中**：Loading 動畫 + 「AI 正在分析收據...」
5. **辨識完成**：顯示品項列表、各項金額、總金額（可編輯）
6. 使用者點擊「匯入」→ 回到 `AddExpenseScreen`，自動填入：
   - 總金額
   - 說明（「收據掃描」）
   - 切換為「項目拆分」模式，填入各品項
   - 收據圖片加入附件

**移除的 UI**：
- 模型下載說明卡（~3.1 GB 說明）
- `LinearProgressIndicator` 下載進度條
- 下載百分比文字

### Decision 6: Feature 層架構（同原設計，datasource 改寫）

遵循 Clean Architecture，在 `features/expenses/` 下的 receipt scanning 子模組架構不變：

```
features/expenses/
├── data/datasources/
│   └── receipt_scan_datasource.dart       # ML Kit OCR + flutter_local_ai 推論 + 圖片預處理
├── data/repositories/
│   └── receipt_scan_repository_impl.dart  # Repository 實作（不變）
├── domain/entities/
│   └── scan_result_entity.dart            # 辨識結果 entity（不變）
├── domain/repositories/
│   └── receipt_scan_repository.dart       # 抽象介面（不變）
├── domain/usecases/
│   └── scan_receipt.dart                  # 掃描收據 use case（不變）
├── domain/utils/
│   └── receipt_parser.dart                # LlmReceiptParser（JSON 解析，不變）
└── presentation/
    ├── providers/
    │   └── receipt_scan_provider.dart      # Riverpod provider（移除下載狀態）
    └── screens/
        └── receipt_scan_result_screen.dart # 結果編輯頁（移除下載/進度 UI）
```

core 層：
```
core/
├── services/
│   └── gemma_model_manager.dart           # 大幅簡化，改封裝 flutter_local_ai
└── providers/
    └── gemma_model_provider.dart           # 不變
```

### Decision 7: 圖片預處理（不變）

使用 `image` package 對圖片做預處理後傳給 ML Kit OCR：
1. `bakeOrientation()` 校正 EXIF 旋轉
2. `copyResize()` 縮放至最長邊 ≤ 768px
3. `encodeJpg(quality: 85)` 輸出為 JPEG

### Decision 8: 平台設定

**iOS**：
- Podfile `platform :ios, '16.0'` 維持不變（app 最低版本）
- 移除 flutter_gemma 相關設定（`use_frameworks! :linkage => :static`、`EXCLUDED_ARCHS`）
- 功能可用性在 runtime 由 `isAvailable()` 判斷，不強制最低版本

**Android**：
- 移除 proguard-rules.pro 中 MediaPipe / Protobuf 相關規則
- 新增 `AndroidManifest.xml` 中 `<uses-library android:name="com.google.android.aicore" android:required="false" />`

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 支援裝置範圍有限（旗艦機才有 Apple Intelligence / AICore） | 不支援裝置直接隱藏入口，不造成使用者困惑；功能為錦上添花，非核心功能 |
| Apple Foundation Models 以英文為主，繁中/日文理解能力待驗證 | ML Kit OCR 已擷取正確文字，LLM 主要做結構化；即使 LLM 輸出不佳，使用者可手動編輯 |
| Android ML Kit GenAI 不支援結構化輸出（tool calling） | 改用 prompt engineering 要求純 JSON 輸出；LlmReceiptParser 已有完整容錯處理 |
| OCR 步驟可能遺漏文字（模糊、手寫） | 辨識結果提供完整編輯介面，使用者可手動修正 |
| LLM 推論速度（依裝置效能） | 顯示明確 loading；90 秒 timeout；結果僅供確認編輯 |
| LLM 輸出可能不符合 JSON 格式 | 防禦性 `LlmReceiptParser`：去除 code fence、容錯前綴文字、null-safe 欄位映射 |
