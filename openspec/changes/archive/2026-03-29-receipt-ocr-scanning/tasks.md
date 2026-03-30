## 1. 依賴與平台整合

- [x] 1.1 在 `app/pubspec.yaml` 納入 `google_mlkit_text_recognition`、`image`、`path_provider`，並保留 `flutter_local_ai` 作為既有 feature gate 能力來源
- [x] 1.2 在 iOS 端建立 `com.okaeri.native_ocr` method channel，使用 `Vision` 實作 `recognizeText`
- [x] 1.3 Android 掃描流程接上 `google_mlkit_text_recognition`

## 2. Data Layer — OCR 與規則式解析

- [x] 2.1 `receipt_scan_datasource.dart` 完成圖片前處理（方向校正、縮圖、灰階、對比增強、暫存檔）
- [x] 2.2 依平台切換 OCR：iOS 走 Vision、Android 走 ML Kit
- [x] 2.3 將 OCR 結果整理成穩定的逐列文字輸出
- [x] 2.4 建立 tokenization + matching heuristics，從文字推導品項與價格
- [x] 2.5 支援 total line / discount line / same-line name+price / barcode fallback 等收據模式
- [x] 2.6 以 `lowConfidence` 標記不穩定的解析結果
- [x] 2.7 掃描後清除 OCR 暫存檔

## 3. Domain / Repository Layer

- [x] 3.1 `ScanResultEntity` 擴充為可承載 `rawText` 與 `lowConfidence`
- [x] 3.2 `ScanResultItemEntity` 支援 `quantity` 與 `unitPrice`
- [x] 3.3 `ReceiptScanRepository` / `ScanReceipt` 封裝掃描流程並保留語言提示參數
- [x] 3.4 `ReceiptScanRepositoryImpl` 將掃描例外轉換為可顯示的 failure 訊息

## 4. Presentation Layer — 掃描結果工作區

- [x] 4.1 `receipt_scan_provider.dart` 建立 `idle / notSupported / scanning / success / error` 狀態
- [x] 4.2 `ReceiptScanResultScreen` 顯示 loading、error、notSupported 與 success 畫面
- [x] 4.3 成功結果可新增 / 刪除 / 修改品項，並在未手動覆寫時自動重算總額
- [x] 4.4 `lowConfidence` 時顯示醒目提醒，要求使用者確認後再匯入
- [x] 4.5 當群組有多個可用幣別時，允許使用者在結果頁選擇匯入幣別
- [x] 4.6 支援對每個品項指定分攤成員，供 itemized split 匯入使用

## 5. 整合 AddExpenseScreen

- [x] 5.1 `AddExpenseScreen` 以 `FlutterLocalAi().isAvailable()` 控制是否顯示掃描入口
- [x] 5.2 掃描入口 bottom sheet 提供語言提示（自動 / 中文 / 日文 / 英文）與影像來源（拍照 / 相簿）
- [x] 5.3 匯入後更新金額，並在描述為空時自動填入 `收據掃描`
- [x] 5.4 當有辨識品項時切換為 itemized split，並以掃描結果覆蓋現有品項列
- [x] 5.5 將收據圖片加入附件列表，並保留付款人與既有表單上下文
- [x] 5.6 將結果頁的幣別與品項成員設定帶回費用表單

## 6. 文件對齊

- [x] 6.1 更新 `proposal.md`，改為描述平台 OCR + rule-based parser 方案
- [x] 6.2 更新 `design.md`，對齊目前 codebase 的平台整合、資料流與風險
- [x] 6.3 更新 `specs/add-expense/spec.md` 與 `specs/receipt-scanning/spec.md`，使需求描述符合現有 UX

## 7. 後續驗證與收斂

- [ ] 7.1 針對繁中 / 日文 / 英文收據建立可重複驗證樣本，確認 parser 命中率與 lowConfidence 行為
- [x] 7.2 為 `receipt_scan_datasource.dart` 的 normalization / token matching 補充單元測試
- [ ] 7.3 實機驗證 iOS Vision 與 Android ML Kit 在常見收據格式上的表現
- [ ] 7.4 評估是否要把掃描入口 gate 從 `FlutterLocalAi().isAvailable()` 改為更貼近 OCR capability 的檢查
- [x] 7.5 強化 OCR candidate scorer，讓候選排序更偏向完整品項名稱與穩定的名稱/價格配對
- [x] 7.6 補強餐飲點餐單格式 heuristics，支援 `單價 x 數量 [總價]`、小額品項與點餐 header metadata 過濾
