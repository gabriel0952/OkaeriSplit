## Purpose
定義 receipt document model capability，讓收據 OCR 結果先被整理為具 layout 與 confidence 的共同結構，供固定欄位、line items、驗證與 heuristics 補強使用。

## Requirements

### Requirement: 系統必須建立收據的 layout-aware document model
系統 SHALL 在 OCR 完成後先建立一個 receipt document model，保留可供後續欄位抽取與驗證使用的結構化 layout 資訊，而不只輸出純文字。

#### Scenario: OCR 完成後建立 document model
- **WHEN** 系統取得收據圖片的 OCR 結果
- **THEN** 系統應產生一個 document model，其中至少包含 block、line、word、text 與對應的 bounding box / reading order

#### Scenario: iOS 與 Android OCR 可映射到共同結構
- **WHEN** 系統分別從 iOS Vision 與 Android ML Kit 取得 OCR 結果
- **THEN** 兩個平台的輸出都應能被映射為同一份 receipt document model 結構

---

### Requirement: 系統必須從 layout model 抽取固定欄位
系統 SHALL 以 receipt document model 為基礎，抽取固定欄位與 line item 結構，而不是直接從純文字輸出最終結果。

#### Scenario: 抽取收據頭尾欄位
- **WHEN** document model 已建立
- **THEN** 系統應嘗試抽取 `merchant`、`subtotal`、`tax` 與 `total`

#### Scenario: 抽取 line items
- **WHEN** document model 中存在可辨識的品項區塊或價格區塊
- **THEN** 系統應嘗試輸出 `line_items[]`，其中每筆至少包含 `name`、`qty`、`unit_price` 與 `amount` 的可用子集

---

### Requirement: 系統必須提供欄位級與 item 級 confidence
系統 SHALL 為 document model 抽取出的欄位與 line item 提供 confidence，而不只保留整體低信心標記。

#### Scenario: 欄位 confidence
- **WHEN** 系統抽取 `merchant`、`subtotal`、`tax` 或 `total`
- **THEN** 每個欄位都應能對應一個 confidence 值或等級

#### Scenario: line item confidence
- **WHEN** 系統抽取 line item
- **THEN** 每筆 line item 應具備 item 級 confidence，供後續 UI 或驗證流程使用

---

### Requirement: 系統必須支援以固定樣本集評估結構化抽取表現
系統 SHALL 能對固定樣本集執行結構化抽取評估，以比較不同流程調整前後的品質變化。

#### Scenario: 評估 item name 命中
- **WHEN** 團隊對固定樣本集執行 evaluation
- **THEN** 系統應能比較預測的 item name 與 ground truth 的命中情形

#### Scenario: 評估 amount 與 total 命中
- **WHEN** 團隊對固定樣本集執行 evaluation
- **THEN** 系統應能比較 line item amount 與 receipt total 的命中情形

---

### Requirement: heuristics 必須建立在結構化抽取之上
系統 SHALL 將 heuristics 視為 layout model 與 field extraction 之上的補強層，而非整個流程的唯一主解析機制。

#### Scenario: 欄位已抽出時補強 heuristics
- **WHEN** 系統已成功抽取大部分固定欄位與 line items
- **THEN** heuristics 應只用於補缺欄位、解歧義或補強特定版型，而不應重新覆寫整個結構化結果

#### Scenario: 結構化結果與 heuristics 衝突
- **WHEN** heuristics 的推導結果與 layout-aware field extraction 結果不一致
- **THEN** 系統應依 confidence 與 validation 規則決定採信結果，而不是無條件優先 heuristic
