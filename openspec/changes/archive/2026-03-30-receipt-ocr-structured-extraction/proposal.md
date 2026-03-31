## Why

目前收據掃描雖然已能以裝置端 OCR 加上規則式 parser 產出可編輯結果，但核心資料流仍以「逐列文字 + heuristic pairing」為主，對多欄版型、欄位抽取、欄位可信度與可重複評估的支撐不足。若要把辨識品質穩定提升到更實用的水準，下一步需要先把流程升級成更結構化的 document understanding pipeline，而不是只持續堆疊零散 heuristics。

## What Changes

- 建立 `receipt document model`，保留 OCR 的 block / line / word / bounding box 等 layout 資訊，而不只輸出純文字
- 新增 field extraction 流程，從 layout model 抽出 `merchant`、`total`、`subtotal`、`tax` 與 `line_items[]`
- 將目前單一 `lowConfidence` 擴充為欄位級與 item 級 confidence
- 建立固定樣本集與評估指標，至少覆蓋 item name、amount、total 命中率
- 將 heuristics 補強放到最後一步，改為建立在 layout、欄位抽取與 confidence 之上

## Capabilities

### New Capabilities
- `receipt-document-model`: 定義 OCR 收據辨識的結構化 layout model、欄位抽取、欄位/item confidence 與 evaluation pipeline

### Modified Capabilities
- `receipt-scanning`: 將收據掃描從純文字導向的規則式解析流程，擴充為可產出 layout-aware document model、欄位抽取結果與欄位級 confidence 的流程

## Impact

- `openspec/specs/receipt-scanning/spec.md`
- 新增 `openspec/changes/receipt-ocr-structured-extraction/specs/receipt-document-model/spec.md`
- 後續可能影響 `receipt_scan_datasource.dart`、`receipt_scan_provider.dart`、`receipt_scan_result_screen.dart`、掃描結果 entity 與測試資料結構
- 後續需要新增固定驗證樣本與評估腳本/流程，以支撐 OCR 調整的比較與回歸
