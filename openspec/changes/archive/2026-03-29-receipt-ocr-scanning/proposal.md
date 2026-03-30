## Why

使用者在記錄消費時仍需要手動輸入金額、品項與附件，對於聚餐、超市、旅行等多品項消費來說步驟偏多，也容易漏填或填錯。OkaeriSplit 目前已經有附件上傳、項目拆分、多幣別與群組成員分攤能力，因此最適合的方向不是新增雲端辨識服務，而是把「收據照片 → 可編輯的費用草稿」整合進現有新增費用流程。

這個 change 最早以「OCR + 系統 LLM」為方向，但目前專案實作已經收斂成更貼近現況的版本：**平台 OCR + Dart rule-based parser**。iOS 端透過 `Vision` method channel 擷取文字，Android 端使用 `google_mlkit_text_recognition`，再由 `receipt_scan_datasource.dart` 內的規則式解析器完成品項與總額抽取。這個版本更符合目前專案對穩定性、可維護性與離線能力的要求，也與既有的 Riverpod / Clean Architecture / editable import flow 更一致。

## What Changes

- **平台別 OCR 管線**：iOS 使用 `Vision` 原生文字辨識（`AppDelegate.swift` 的 `com.okaeri.native_ocr` channel），Android 使用 `google_mlkit_text_recognition`
- **規則式解析器**：以 Dart 內的 tokenization + matching heuristics 解析 OCR 結果，不依賴 LLM 或雲端 API
- **圖片預處理**：掃描前會做 EXIF 方向校正、縮圖、灰階與對比增強，提高 OCR 可讀性
- **低信心提示**：當規則式解析命中率低、價格推論不穩或總額與品項加總差異偏大時，結果頁顯示提醒，但仍允許使用者手動修正後匯入
- **完整掃描編輯流程**：新增費用頁提供掃描入口，支援拍照/相簿、OCR 語言提示、結果預覽編輯、幣別選擇、每個品項的分攤成員指定，再匯入表單
- **表單整合**：匯入時更新金額，必要時切換為項目拆分，帶入收據圖片附件，並盡量保留既有費用表單上下文（付款人、群組成員等）
- **保守功能入口策略**：目前 UI 沿用 `FlutterLocalAi().isAvailable()` 作為掃描入口顯示條件，屬於現階段專案中的保守 feature gate

## Capabilities

### New Capabilities
- `receipt-scanning`: 收據圖片辨識核心能力 — 包含平台 OCR、規則式品項/總額解析、低信心提示、結果預覽編輯、匯入費用表單

### Modified Capabilities
- `add-expense`: 新增費用流程新增「掃描收據」入口，支援選擇 OCR 語言提示、從辨識結果自動填入表單欄位（金額、說明、項目拆分、附件、幣別與品項分攤）

## Impact

- **新增依賴**：`flutter_local_ai: ^0.0.6`（目前用於 feature gate）、`google_mlkit_text_recognition: ^0.15.1`（Android OCR）、`image: ^4.2.0`（圖片預處理）、`path_provider: ^2.1.4`
- **移除依賴**：舊的本地 LLM 實驗路徑（`flutter_gemma`、`llamafu`）不再是此功能主體
- **後端**：無需後端變更，所有辨識皆在本地完成
- **費用**：無 API 費用，完全免費（on-device processing）
- **平台實作**：
  - iOS：`Vision` + method channel
  - Android：ML Kit Text Recognition + row regrouping
- **平台要求**：
  - iOS：OCR 實作基於 `Vision`；結果頁文案目前以 iOS 16+ 為基準
  - Android：OCR 實作基於 ML Kit；入口是否顯示目前仍受 `FlutterLocalAi().isAvailable()` gate 影響
- **現有程式碼影響**：
  - `add_expense_screen.dart` — 掃描入口、語言選擇、匯入結果回填
  - `receipt_scan_result_screen.dart` — 編輯/刪除/新增品項、幣別選擇、品項成員指定、低信心提示
  - `receipt_scan_datasource.dart` — 平台 OCR + rule-based parser + 圖片前處理
  - `ios/Runner/AppDelegate.swift` — 原生 Vision OCR method channel
  - `pubspec.yaml` — OCR 與圖片處理依賴
