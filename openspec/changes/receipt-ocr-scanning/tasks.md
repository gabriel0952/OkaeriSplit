## 1. 環境設定與依賴

- [x] 1.1 在 `pubspec.yaml` 移除 `flutter_gemma`、`llamafu`，新增 `flutter_local_ai: ^0.0.6`、`google_mlkit_text_recognition: ^0.13.0`、`image: ^4.2.0`、`path_provider: ^2.1.4`
- [x] 1.2 設定 iOS `Podfile`：還原為標準 framework 連結（移除 `use_frameworks! :linkage => :static` 與 `EXCLUDED_ARCHS` 設定）；platform 維持 `ios, '16.0'`
- [x] 1.3 移除 `android/app/proguard-rules.pro` 中 MediaPipe / Protobuf 相關規則
- [x] 1.4 在 `android/app/src/main/AndroidManifest.xml` 新增 `<uses-library android:name="com.google.android.aicore" android:required="false" />`
- [x] 1.5 移除 `dart_defines.example.json` 中的 `HF_TOKEN` 欄位
- [x] 1.6 確認 `main.dart` 無殘留 `FlutterGemma.initialize()` 呼叫（已移除）

## 2. Core Layer — AI 可用性管理

- [x] 2.1 改寫 `core/services/gemma_model_manager.dart`：移除所有下載邏輯，封裝 `flutter_local_ai` 可用性檢查與 LLM 呼叫
- [x] 2.2 更新 `ModelDownloadState` sealed class，移除 `ModelDownloading`，新增 `ModelNotSupported`
- [x] 2.3 實作 `isAvailable()`：呼叫 `FlutterLocalAi().isAvailable()`，取代原本 `isModelDownloaded()`
- [x] 2.4 實作 `getReadyModel()`：回傳已 initialize 的 `FlutterLocalAi` 實例（帶系統 prompt）
- [x] 2.5 移除 `downloadModel()` 方法與相關 HTTP 下載邏輯
- [x] 2.6 `core/providers/gemma_model_provider.dart` 移除 `modelDownloadStateProvider`（下載狀態不再需要）

## 3. Domain Layer — 資料模型（不變）

- [x] 3.1 `ScanResultEntity`（freezed data class）：包含 `items`、`total` 欄位
- [x] 3.2 `ScanResultItemEntity`（freezed data class）：包含 `name`、`quantity`、`amount` 欄位

## 4. Domain Layer — LLM 收據解析器（不變）

- [x] 4.1 `LlmReceiptParser.parse(String llmResponse)` 於 `domain/utils/receipt_parser.dart`
- [x] 4.2 code fence 去除（````json...```）
- [x] 4.3 JSON 邊界定位（容錯 LLM 前綴文字）
- [x] 4.4 防禦性 null/type handling（number-as-string、缺少欄位、malformed JSON 回傳空 items）
- [x] 4.5 items 映射為 `ScanResultItemEntity` list

## 5. Data Layer — OCR + LLM DataSource

- [x] 5.1 改寫 `receipt_scan_datasource.dart`：移除 flutter_gemma / llamafu，改為兩段式（ML Kit OCR → flutter_local_ai）
- [x] 5.2 實作 `_preprocessImageToFile()`：decode → `bakeOrientation()` → resize ≤ 768px → JPEG encode → 存 temp file（供 ML Kit 使用）
- [x] 5.3 實作 `_extractTextFromImage(File)`：呼叫 `google_mlkit_text_recognition` 擷取圖片文字，回傳 `String`
- [x] 5.4 實作 `scanReceipt(File imageFile)`：圖片預處理 → OCR → 組裝 prompt（含 OCR 文字）→ `FlutterLocalAi().generateTextSimple()` → `LlmReceiptParser.parse()`
- [x] 5.5 設定 prompt 要求 LLM 輸出純 JSON（保留原始語言，不翻譯）
- [x] 5.6 加入 90 秒 timeout（`Future.timeout(Duration(seconds: 90))`）
- [x] 5.7 finally 清除 temp image file

## 6. Domain Layer — Use Case & Repository（不變）

- [x] 6.1 `ReceiptScanRepository` 抽象介面：`call({required File imageFile})`
- [x] 6.2 `ScanReceiptUseCase`：`call({required File imageFile})`
- [x] 6.3 `ReceiptScanRepositoryImpl`：捕捉 `TimeoutException` 與一般 Exception

## 7. Presentation Layer — Provider

- [x] 7.1 更新 `ScanStatus` enum：移除 `modelNotDownloaded`、`downloading`，新增 `notSupported`
- [x] 7.2 更新 `ReceiptScanState`：移除 `downloadProgress` 欄位
- [x] 7.3 `ReceiptScanNotifier` 移除 `GemmaModelManager` 注入，改為直接呼叫 `isAvailable()`
- [x] 7.4 更新 `scan(imageFile)`：先 `isAvailable()`；若否 → 設 `notSupported` 狀態；若是 → 直接執行 `_runScan()`
- [x] 7.5 移除 `downloadModelAndScan()` 方法與 `StreamSubscription` 監聽

## 8. Presentation Layer — 辨識結果頁面

- [x] 8.1 移除 `ReceiptScanResultScreen` 中的下載說明卡 UI（`modelNotDownloaded` 狀態）
- [x] 8.2 移除 `LinearProgressIndicator` 下載進度 UI（`downloading` 狀態）
- [x] 8.3 新增 `notSupported` UI：顯示「此裝置不支援 AI 辨識功能」訊息卡
- [x] 8.4 維持 `scanning` loading 文字「AI 正在分析收據...」
- [x] 8.5 確認 Switch 涵蓋所有更新後的 `ScanStatus` 值

## 9. 整合 AddExpenseScreen

- [x] 9.1 新增 `_isAiAvailable` 狀態，`initState` 時呼叫 `FlutterLocalAi().isAvailable()` 初始化
- [x] 9.2 `_isAiAvailable` 為 false 時隱藏「掃描收據」按鈕
- [x] 9.3 確認 `ReceiptScanResultScreen` 呼叫不帶任何已移除的參數

## 10. 測試與驗證

- [x] 10.1 `flutter analyze` — 確認無殘留 `flutter_gemma`、`llamafu`、`FlutterGemma` 引用
- [ ] 10.2 Build 測試：`flutter build ios`（無 dart-define 需求）
- [ ] 10.3 支援裝置實機測試（iOS 18.1+，iPhone 15 Pro 以上）：進入掃描 → 辨識中 → 結果
- [ ] 10.4 不支援裝置測試（iOS < 18.1 或舊機型）：確認掃描按鈕隱藏
- [ ] 10.5 三語言收據測試：繁中/英文/日文各一張，驗證 items + total
- [ ] 10.6 辨識結果編輯測試：新增/刪除/修改品項，確認金額即時更新
- [ ] 10.7 匯入費用表單測試：確認金額、說明、項目拆分、附件正確填入
- [ ] 10.8 LlmReceiptParser 單元測試：code fence、number-as-string、malformed JSON 輸入
- [ ] 10.9 Timeout 測試：模擬推論超過 90 秒，確認回傳錯誤而非 hang
- [ ] 10.10 Android 支援裝置測試（Pixel 8+ 或 Samsung S24+）：確認 ML Kit GenAI 可用
