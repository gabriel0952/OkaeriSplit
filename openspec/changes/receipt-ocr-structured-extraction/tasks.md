## 1. Step 1 — Layout understanding

- [x] 1.1 定義 receipt document model 的 entities / DTO，至少涵蓋 page、block、line、word、text、normalized text、bounding box 與 reading order
- [x] 1.2 盤點 iOS Vision 與 Android ML Kit 可取得的 OCR 幾何資訊，設計共同映射層
- [x] 1.3 調整 `receipt_scan_datasource.dart`，讓 OCR 流程除了純文字外也能產出 layout-aware document model
- [x] 1.4 建立 adapter，確認新 document model 仍可向下轉換為目前掃描結果頁需要的資料

## 2. Step 2 — Field extraction

- [x] 2.1 定義 `merchant`、`subtotal`、`tax`、`total` 與 `line_items[] {name, qty, unit_price, amount}` 的抽取結果結構
- [x] 2.2 以 document model 為基礎建立 field extraction 流程，先抽取頭尾欄位，再抽取 line items
- [x] 2.3 建立從 field extraction 結果映射到現有 `ScanResultEntity` / 結果頁顯示資料的轉換層
- [x] 2.4 針對多欄、弱雙欄與常見零售/餐飲版型補齊最小可用抽取規則

## 3. Step 3 — Confidence

- [x] 3.1 定義 document、field、item 三層 confidence 模型
- [x] 3.2 為 `merchant`、`subtotal`、`tax`、`total` 抽取建立欄位級 confidence
- [x] 3.3 為 line item 建立 item 級 confidence，並定義如何聚合為整體 `lowConfidence`
- [x] 3.4 更新掃描結果狀態與轉換流程，讓 UI 仍可顯示簡化提示，同時保留較細緻的 confidence 資訊

## 4. Step 4 — Evaluation

- [x] 4.1 建立固定驗證樣本集格式與 baseline 樣本清單
- [x] 4.2 定義核心評估指標，至少包含 item name 命中、amount 命中、total 命中
- [x] 4.3 建立可重複執行的 evaluation 流程，用於比較 OCR / extraction 調整前後結果
- [x] 4.4 把高風險案例轉為自動化測試或固定 regression case

## 5. Step 5 — Heuristics 補強

- [x] 5.1 重新整理現有 heuristics，區分哪些屬於 layout 補強、欄位補強、pairing 補強或版型特例
- [x] 5.2 將 pairing、欄位規則與特定版型補強改寫為建立在 layout / field extraction / confidence 之上的補強層
- [x] 5.3 以固定樣本集驗證 heuristics 補強是否提升 item name、amount 與 total 命中率
- [x] 5.4 針對高價值常見版型（如日本零售、餐飲點餐單、稅額複雜收據）規劃後續專項補強順序
