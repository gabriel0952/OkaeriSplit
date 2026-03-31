## ADDED Requirements

### Requirement: 收據掃描流程必須保留可供結構化抽取使用的 OCR 幾何資訊
`receipt-scanning` capability SHALL 在 OCR 流程中保留 block / line / word 與 bounding box 等資訊，供後續建立 receipt document model 使用。

#### Scenario: OCR 結果不再只輸出純文字
- **WHEN** 系統完成 OCR 候選收集
- **THEN** 內部流程應能取得不只純文字的幾何與結構資訊，而不是僅保留最終文字串

#### Scenario: 結構化資訊可轉回現有掃描結果頁
- **WHEN** 系統已完成 layout-aware 抽取
- **THEN** 仍應能將結果轉換為目前掃描結果頁可使用的資料格式

---

### Requirement: 收據掃描流程必須先做 field extraction，再輸出可編輯結果
`receipt-scanning` capability SHALL 先從 receipt document model 抽取固定欄位與 line items，再生成結果頁所需的可編輯資料。

#### Scenario: 抽取 merchant 與金額欄位
- **WHEN** 系統完成 layout-aware field extraction
- **THEN** 掃描流程應能輸出 `merchant`、`subtotal`、`tax` 與 `total` 的抽取結果

#### Scenario: 抽取 line items 並映射到結果頁
- **WHEN** 系統抽取出 line items
- **THEN** 掃描流程應將 line items 映射為結果頁可編輯的品項資料，而不是只依賴逐列文字 pairing

---

### Requirement: 收據掃描流程必須以欄位級與 item 級 confidence 驅動結果提示
`receipt-scanning` capability SHALL 以欄位級與 item 級 confidence 聚合結果提示，而不是只依賴單一整體 `lowConfidence` 判斷。

#### Scenario: 個別欄位低信心
- **WHEN** `merchant`、`total` 或某筆 line item 的 confidence 偏低
- **THEN** 系統應能在內部識別該欄位/品項為高風險結果

#### Scenario: 整體 lowConfidence 由細部 confidence 聚合
- **WHEN** 系統需要決定是否顯示整體低信心提示
- **THEN** `lowConfidence` 應可由欄位級與 item 級 confidence 加總或聚合得出

---

### Requirement: 收據掃描流程必須支援固定樣本集回歸評估
`receipt-scanning` capability SHALL 能以固定樣本集與明確指標驗證流程調整前後的效果。

#### Scenario: 比較 item name 命中
- **WHEN** 團隊修改 layout reconstruction、field extraction 或 heuristics
- **THEN** 團隊必須能比較固定樣本集中 item name 的命中表現

#### Scenario: 比較 amount 與 total 命中
- **WHEN** 團隊修改 layout reconstruction、field extraction 或 heuristics
- **THEN** 團隊必須能比較固定樣本集中 amount 與 total 的命中表現

---

### Requirement: heuristics 補強必須晚於 layout、field extraction、confidence 與 evaluation
`receipt-scanning` capability SHALL 將 pairing、欄位規則與特定版型補強放在 layout understanding、field extraction、confidence 與 evaluation 基礎建立之後。

#### Scenario: 規劃特定版型補強
- **WHEN** 團隊準備新增針對特定店家或版型的 heuristics
- **THEN** 該補強應建立在既有 layout model、欄位抽取與 confidence 機制之上

#### Scenario: 尚未建立評估基準時避免優先新增 heuristics
- **WHEN** 團隊尚未建立固定樣本集與核心命中指標
- **THEN** 不應將零散 heuristics 視為主要優先項目
