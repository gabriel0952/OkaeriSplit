## 1. 環境設定與依賴

- [x] 1.1 在 `pubspec.yaml` 移除 `google_mlkit_text_recognition`，新增 `flutter_gemma: ^0.12.0`、`image: ^4.2.0`、`path_provider: ^2.1.4`、`http: ^1.2.2`
- [x] 1.2 設定 iOS `Podfile`：升至 `platform :ios, '16.0'`；改為 `use_frameworks! :linkage => :static`；post_install 統一設定 `IPHONEOS_DEPLOYMENT_TARGET = '16.0'`；新增 `EXCLUDED_ARCHS[sdk=iphonesimulator*] = 'arm64'`
- [x] 1.3 新增 `android/app/proguard-rules.pro`，保留 MediaPipe / Protobuf 類別
- [x] 1.4 更新 `android/app/build.gradle.kts` release buildType 加入 proguardFiles
- [x] 1.5 新增 `dart_defines.example.json`，加入 `HF_TOKEN` 範本欄位
- [x] 1.6 在 `main.dart` 加入 `FlutterGemma.initialize()` 於 `runApp` 前（必要初始化步驟）

## 2. Core Layer — 模型管理

- [x] 2.1 建立 `core/services/gemma_model_manager.dart`：`GemmaModelManager` 單例，廣播 `Stream<ModelDownloadState>`
- [x] 2.2 實作 `ModelDownloadState` sealed class（`ModelNotDownloaded` / `ModelDownloading(progress)` / `ModelReady` / `ModelDownloadError(message)`）
- [x] 2.3 實作 `isModelDownloaded()`：呼叫 `FlutterGemma.isModelInstalled(filename)`
- [x] 2.4 實作 `downloadModel()`：透過 `FlutterGemma.installModel().fromNetwork(url, token:).withProgress(cb).install()` 下載並回報進度
- [x] 2.5 實作 `getReadyModel()`：回傳 `FlutterGemma.getActiveModel(maxTokens: 512, supportImage: true)`
- [x] 2.6 建立 `core/providers/gemma_model_provider.dart`：`gemmaModelManagerProvider`、`modelDownloadStateProvider`

## 3. Domain Layer — 資料模型

- [x] 3.1 建立 `ScanResultEntity`（freezed data class）：包含 `items`、`total` 欄位
- [x] 3.2 建立 `ScanResultItemEntity`（freezed data class）：包含 `name`、`quantity`、`amount` 欄位

## 4. Domain Layer — LLM 收據解析器

- [x] 4.1 移除舊 `ReceiptParser`（RegEx 解析器）與 `ReceiptLanguage` enum
- [x] 4.2 建立 `LlmReceiptParser.parse(String llmResponse)` 於 `domain/utils/receipt_parser.dart`
- [x] 4.3 實作 code fence 去除（````json...```）
- [x] 4.4 實作 JSON 邊界定位（容錯 LLM 前綴文字）
- [x] 4.5 實作防禦性 null/type handling（number-as-string、缺少欄位、malformed JSON 回傳空 items）
- [x] 4.6 實作 items 映射為 `ScanResultItemEntity` list

## 5. Data Layer — LLM DataSource

- [x] 5.1 完全改寫 `receipt_scan_datasource.dart`：移除 ML Kit，改用 `GemmaModelManager`
- [x] 5.2 實作 `_preprocessImage()`：decode → `bakeOrientation()` → resize ≤ 1024px → JPEG encode
- [x] 5.3 實作 `scanReceipt(File imageFile)`：預處理 → `getReadyModel()` → `createChat(supportImage:true)` → `Message.withImage()` → `generateChatResponse()` → `LlmReceiptParser.parse()`
- [x] 5.4 設定低 temperature（0.1）/ topK=1 確保 LLM 輸出穩定
- [x] 5.5 加入 60 秒 timeout（`Future.timeout(Duration(seconds: 60))`）

## 6. Domain Layer — Use Case & Repository

- [x] 6.1 更新 `ReceiptScanRepository` 抽象介面：移除 `language` 參數
- [x] 6.2 更新 `ScanReceiptUseCase`：移除 `language` 參數，簽名改為 `call({required File imageFile})`
- [x] 6.3 更新 `ReceiptScanRepositoryImpl`：移除 language；新增捕捉 `StateError`（model not ready）與 `TimeoutException`

## 7. Presentation Layer — Provider

- [x] 7.1 擴充 `ScanStatus` enum：新增 `modelNotDownloaded`、`downloading` 狀態
- [x] 7.2 擴充 `ReceiptScanState`：新增 `downloadProgress: double`
- [x] 7.3 `ReceiptScanNotifier` 注入 `GemmaModelManager`
- [x] 7.4 實作 `scan(imageFile)`：先 `isModelDownloaded()`；若否 → 設 `modelNotDownloaded` 狀態
- [x] 7.5 實作 `downloadModelAndScan(imageFile)`：監聽 `stateStream`，更新 progress，完成後自動呼叫 `_runScan()`
- [x] 7.6 Datasource provider 注入 `GemmaModelManager`

## 8. Presentation Layer — 辨識結果頁面

- [x] 8.1 更新 `ReceiptScanResultScreen`：移除 `language` 建構參數
- [x] 8.2 實作 `modelNotDownloaded` UI：說明卡（模型大小 ~3.1GB）+ 「下載並辨識」按鈕
- [x] 8.3 實作 `downloading` UI：`LinearProgressIndicator(value: downloadProgress)` + 百分比文字
- [x] 8.4 更新 scanning loading 文字為「AI 正在分析收據...」
- [x] 8.5 Switch 涵蓋全部 6 個 `ScanStatus` 值

## 9. 整合 AddExpenseScreen

- [x] 9.1 移除 `ReceiptLanguage` import 與 `_ScanConfig` 私有類別
- [x] 9.2 `_startReceiptScan()` 底部選單簡化為純拍照/相簿選擇（無語言選擇器）
- [x] 9.3 `ReceiptScanResultScreen` 建構呼叫移除 `language:` 參數

## 10. 測試與驗證

- [ ] 10.1 `flutter analyze` — 確認無殘留 `ReceiptLanguage` 或 `google_mlkit` 引用
- [ ] 10.2 Build 測試：`flutter build ios --dart-define-from-file=dart_defines.json`
- [ ] 10.3 實機測試（iOS 16.0+ 實體裝置）：首次進入掃描 → 下載提示 → 進度條 → 完成後自動掃描
- [ ] 10.4 三語言收據測試：繁中/英文/日文各一張，驗證 items + total
- [ ] 10.5 辨識結果編輯測試：新增/刪除/修改品項，確認金額即時更新
- [ ] 10.6 匯入費用表單測試：確認金額、說明、項目拆分、附件正確填入
- [ ] 10.7 LlmReceiptParser 單元測試：code fence、number-as-string、malformed JSON 輸入
- [ ] 10.8 Timeout 測試：模擬推論超過 60 秒，確認回傳錯誤而非 hang
- [ ] 10.9 記憶體測試：重複掃描多次，確認 session 正確關閉無洩漏
- [ ] 10.10 Android release build 測試：確認 ProGuard 規則正確，MediaPipe 類別未被混淆
