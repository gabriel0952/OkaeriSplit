## Context

OkaeriSplit 已支援新增費用、項目拆分、收據附件上傳、多幣別與群組成員分攤；因此收據掃描功能最重要的不是「辨識完成後得到一段文字」，而是把照片直接轉成可編輯的費用表單草稿。

這個 change 起初曾探索 OCR + LLM 路線，但目前專案實際已落地的做法是：

1. **圖片預處理**：校正方向、縮圖、灰階、提升對比
2. **平台 OCR**：
   - iOS：透過 `Vision` method channel 辨識文字
   - Android：透過 `google_mlkit_text_recognition`
3. **規則式解析**：在 Dart 內將 OCR 文字切成名稱/價格 token，再推導品項與總額
4. **人工校正**：結果頁提供品項、金額、幣別與分攤成員編輯，再匯入新增費用表單

這個版本比較符合目前專案實際依賴、平台整合方式與既有 UX。

## Goals / Non-Goals

**Goals:**
- 使用者可拍照或選取收據圖片，在裝置上完成 OCR 與品項/總額解析
- 支援中文（繁體）、日文、英文收據，並允許使用者在掃描前提供 OCR 語言提示
- 辨識結果可預覽、編輯後一鍵匯入費用表單（自動填入金額、項目拆分、附件）
- 完全離線可用（無需網路連線即可辨識）
- 無 API 費用
- 與現有 Add Expense 表單、多幣別與 group members 流程整合

**Non-Goals:**
- 不做即時相機掃描（非 live camera stream，而是拍照後辨識）
- 不做發票載具自動歸戶或電子發票 API 串接
- 不做辨識歷史紀錄儲存
- 不做 100% 完美解析 — 辨識結果供使用者確認編輯
- 不引入雲端 OCR / LLM fallback
- 不在此 change 內重做 feature gate 策略

## Decisions

### Decision 1: 使用平台 OCR，而不是 LLM 推論

**選擇**：以平台 OCR 擷取文字，再由 Dart rule-based parser 解析結構化品項。

**平台實作**：

| 平台 | OCR 實作 |
|------|----------|
| iOS | `Vision` + `MethodChannel('com.okaeri.native_ocr')` |
| Android | `google_mlkit_text_recognition` |

**排除或淡化的方案**：

| 方案 | 排除原因 |
|------|----------|
| Cloud OCR / LLM | 需要網路與額外成本，不符合專案方向 |
| 本地多模態 LLM | 體積、記憶體、整合成本與目前專案需求不成比例 |
| 單純把 OCR 原文丟回 UI | 對使用者價值太低，仍要自行整理品項與金額 |

**流程**：
```
圖片
  → 圖片預處理
  → 平台 OCR（Vision / ML Kit）
  → 規則式 tokenization + matching
  → ScanResultEntity
  → ReceiptScanResultScreen 編輯 / 匯入
```

**理由**：
- 與目前已存在的 iOS / Android OCR 能力相容
- 不需要模型推論，避免額外效能與整合風險
- Rule-based parser 可以針對台日常見收據格式持續調整
- 配合結果頁編輯能力，可靠度足以支撐使用者流程

### Decision 2: 保留目前的保守 feature gate

**選擇**：`AddExpenseScreen` 在 `initState()` 時呼叫 `FlutterLocalAi().isAvailable()`，僅在回傳 `true` 時顯示「掃描收據」入口。

**現況說明**：
- 這個 gate 來自先前 AI 能力檢查的專案做法，與當前 OCR implementation 並非完全同一層責任
- 但它確實是目前產品中的入口顯示條件，因此規劃文件需要據實反映
- `ReceiptScanResultScreen` 仍保留 `notSupported` 狀態 UI，方便未來整合更完整的能力檢查

**理由**：先描述目前專案真實行為，後續若要把 gate 改為 OCR capability check，可再另開 follow-up

### Decision 3: 以規則式 token parser 取代 JSON / LLM parser 作為主流程

**選擇**：在 `ReceiptScanDatasource` 內直接對 OCR 文字執行兩階段解析：

1. **Tokenize**：將每一行分類為 name token、price token、noise 或 total line
2. **Match**：在品項名稱附近尋找最合理的價格，推導 `ScanResultItemEntity`

**解析重點**：
```
- `_normalizeLine()` 做常見 OCR 誤判修正（全形轉半形、錯誤分隔符、`¥1.380 → ¥1,380` 等）
- `_normalizeLine()` 也會修正常見點餐單乘號誤判（如 `% / k / K / SOX`）與破損千分位格式
- `_isItemName()` / `_isTotalLine()` / `_isDiscountLine()` 分辨品項、總額與折扣語境
- `_trySameLine()` / `_tryOrderStyleSameLine()` 可直接解析同列 `單價 x 數量 [總價]` 的餐飲點餐單格式
- `_matchTokens()` 依距離與 price tier 為品項配對最可信的價格，並保留 quantity / unitPrice
- `_inferTotal()` 在 footer 或品項加總之間推導總額
- `lowConfidence` 在以下情況設為 `true`：
  - 沒抓到品項
  - 使用低可信價格型別（P0）
  - 品項總額與總計誤差超過容忍範圍
```

**理由**：直接對 OCR 結果做解析，更符合目前 codebase，也能針對常見 receipt 格式細修 heuristics

### Decision 4: 多候選 OCR 以 parser-aware scorer 決定最佳結果

**選擇**：同一張圖片可在不同語言提示與多次 pass 下產生多個 OCR 候選，最後不單看文字長度，而是以 parser-aware scorer 選出最適合匯入的結果。

**評分重點**：

```
- descriptive item count：有多少品項名稱看起來可讀且非 fallback
- item name quality：名稱中的 CJK / 拉丁 / 數字比例、長度是否合理、雜訊是否過多
- pairing stability：名稱與價格的行距、price tier、候選價格競爭程度、最佳配對 margin
- fallback / metadata penalty：條碼 fallback、表頭資訊誤入品項時扣分
- lowConfidence / total presence：低可信結果降權，能穩定推導總額者加分
```

**理由**：
- 同一張收據的 OCR 原文長度不一定代表可用性
- 對使用者來說，「品名完整」與「價格配對正確」比「辨識出更多雜訊字元」重要
- 這樣的 scorer 更適合持續疊代 parser 規則，而不需要回頭引入 LLM 選擇器
### Decision 5: 掃描前保留語言提示，掃描後交由人工校正兜底

**選擇**：在底部 sheet 讓使用者選擇 OCR 語言提示（`auto` / `chinese` / `japanese` / `english`），之後仍以結果頁人工修正作為最後保險。

**iOS 語言策略**：
- `chinese`：`zh-Hant`, `zh-Hans`, `ja`, `en-US`
- `english`：`en-US`, `zh-Hant`, `zh-Hans`, `ja`
- `auto` / `japanese`：`ja`, `zh-Hant`, `zh-Hans`, `en-US`

**Android 現況**：
- 目前使用 `TextRecognitionScript.chinese` 作為主要腳本
- 之後若實機驗證顯示有必要，可再擴充更細緻的語言策略

**理由**：比「完全自動」更符合現有 UI，也更貼近目前原生 iOS channel 的設計

### Decision 6: 結果頁就是真正的資料整理工作區

**更新後流程**：
1. `AddExpenseScreen` 啟動時檢查 gate，符合條件才顯示掃描入口
2. 使用者點擊「掃描收據」→ 底部 sheet 選擇語言提示 + 拍照/相簿
3. 選取圖片後導航至 `ReceiptScanResultScreen`
4. **辨識中**：Loading 動畫 + 「AI 正在分析收據...」
5. **辨識完成**：顯示照片預覽、低信心警示、總額、幣別、品項列表
6. 使用者可編輯：
   - 新增 / 刪除 / 修改品項
   - 修改總額
   - 選擇匯入幣別
   - 對每個品項指定分攤成員
7. 使用者點擊「匯入」→ 回到 `AddExpenseScreen`，自動填入：
   - 總金額
   - 說明（僅在原本為空時填入 `收據掃描`）
   - 若有品項則切換為「項目拆分」模式並覆蓋現有項目
   - 收據圖片加入附件
   - 選定幣別與每個品項的成員設定

**理由**：收據掃描不追求一次成功到可直接送出，而是追求「快速產生可編輯草稿」

### Decision 7: Feature 層維持既有 clean architecture 分層

遵循 Clean Architecture，在 `features/expenses/` 下的 receipt scanning 子模組架構不變：

```
features/expenses/
├── data/datasources/
│   └── receipt_scan_datasource.dart       # 平台 OCR + heuristic parser + 圖片預處理
├── data/repositories/
│   └── receipt_scan_repository_impl.dart  # Repository 實作與例外轉換
├── domain/entities/
│   └── scan_result_entity.dart            # items / total / rawText / lowConfidence
├── domain/repositories/
│   └── receipt_scan_repository.dart       # 抽象介面
├── domain/usecases/
│   └── scan_receipt.dart                  # 掃描收據 use case
├── domain/utils/
│   └── receipt_parser.dart                # 舊 LLM parser，保留但非目前主流程
└── presentation/
    ├── providers/
    │   └── receipt_scan_provider.dart     # Riverpod provider / scan state
    └── screens/
        └── receipt_scan_result_screen.dart # 結果編輯頁
```

相關 core / platform：
```
core/
├── services/
│   └── gemma_model_manager.dart           # 目前保留為 availability helper
└── providers/
    └── gemma_model_provider.dart

ios/Runner/
└── AppDelegate.swift                      # Vision OCR method channel
```

### Decision 8: 圖片預處理要偏向 OCR 友善，而不是附件原圖保真

使用 `image` package 對圖片做預處理後再送入 OCR：
1. `bakeOrientation()` 校正 EXIF 旋轉
2. `copyResize()` 縮放至最長邊 ≤ 1280px
3. `grayscale()` + `adjustColor(contrast: 1.4)` 提升文字對比
4. `encodeJpg(quality: 92)` 輸出為暫存 JPEG

### Decision 9: 錯誤處理與信心傳達以 UX 為中心

**選擇**：
- OCR 完全失敗或解析不到品項/總額時，provider 進入 `error`
- 若能解析但可信度偏低，仍顯示結果頁，並用 warning banner 提醒使用者確認
- Repository 層保留 `TimeoutException` / `StateError` / generic error 轉為 `Failure`

**理由**：
- 對掃描流程來說，「可修正的半成品」通常比「直接失敗」更有價值
- 使用者本來就在匯入前會做最後確認

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 收據格式非常多，rule-based parser 可能持續遇到新 edge cases | 保留 `_normalizeLine()` / token tier / lowConfidence 機制，並持續用實際樣本調整 |
| iOS 與 Android OCR 行為不同 | 在 datasource 中統一輸出為按列整理後的文字，再進入同一套 parser |
| 目前 gate 與實際 OCR capability 並不完全一致 | 文件據實記錄，並在 tasks 中列為 follow-up |
| OCR 可能抓不到完整品項或總額 | 提供完整編輯 UI 與手動新增品項能力 |
| 匯入可能覆蓋使用者現有 itemized items | 明確把結果頁定位為「產生新草稿」，並保留付款人/群組成員等其他上下文 |
