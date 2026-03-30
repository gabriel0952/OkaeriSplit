## Context

目前收據掃描流程以裝置端 OCR 為核心，會先做圖片前處理、收集多個 OCR 候選，再將最佳候選整理成逐列文字，最後由 rule-based parser 直接推導品項與總額。這樣的設計對快速交付很有效，但它把 `layout understanding`、`field extraction`、`confidence` 與 `evaluation` 幾乎全部壓縮在 heuristics 階段，因此當版型變複雜或 OCR 順序不穩時，問題很難被單獨定位與修正。

這次規劃的目標是把現有流程升級為較結構化的 receipt pipeline，同時仍維持目前的 on-device OCR 路線。新的架構會把流程拆成五步：先保留 OCR 幾何資訊建立 `receipt document model`，再從 layout model 抽取固定欄位，接著對欄位與 line item 建立 confidence，並以固定樣本集做評估，最後才把 heuristics 視為在結構化結果之上的補強層。

## Goals / Non-Goals

**Goals:**
- 定義 `receipt document model`，保留 block / line / word / bounding box 等 layout 資訊
- 將 `merchant`、`subtotal`、`tax`、`total` 與 `line_items[]` 的抽取獨立成明確階段
- 將 confidence 從整體 `lowConfidence` 擴充到欄位級與 item 級
- 建立固定樣本集與核心評估指標，用於比較不同 OCR / extraction 調整的效果
- 讓 heuristics 後移成補強層，而不是唯一的主解析流程

**Non-Goals:**
- 不改採雲端 OCR 或第三方收據專用服務
- 不在此 change 中完成完整 feedback loop 或模型訓練系統
- 不追求一次支援所有全球收據版型；優先聚焦 OkaeriSplit 目前高頻使用場景

## Decisions

### 1. 以 `receipt document model` 作為 OCR 與解析之間的中介層
新的主資料流不再只產生純文字，而是先生成一個結構化 model，至少包含：
- page / image metadata
- blocks
- lines
- words
- 每個節點的 text、normalized text、bounding box、reading order

這樣能把 OCR 問題與 parser 問題拆開。若品項配錯，之後可以知道是 OCR geometry 不穩、行排序錯、欄位抽取錯，還是 heuristics 判斷錯。相比沿用目前「直接把 OCR 輸出壓成文字再 parser」，這會增加資料模型複雜度，但可顯著改善可觀測性。

### 2. 欄位抽取獨立為 `field extraction` 階段
欄位抽取需明確產出：
- `merchant`
- `subtotal`
- `tax`
- `total`
- `line_items[] { name, qty, unit_price, amount }`

抽取邏輯優先依賴 layout 與語意線索，而不是直接以最終 heuristic 生成 `ScanResultEntity`。這樣能讓 UI 或後續 parser 知道目前哪些欄位其實已被穩定抽出，哪些欄位仍需要補強。相比把所有邏輯都維持在 token pairing 內，這更接近主流 document extraction pipeline。

### 3. confidence 分為三層
confidence 不再只保留單一 `lowConfidence`：
- `documentConfidence`: 整體掃描結果是否穩定
- `fieldConfidence`: `merchant`、`subtotal`、`tax`、`total` 等欄位級 confidence
- `itemConfidence`: 每個 line item 的 name / qty / unit_price / amount 的 confidence，至少有 item 級總分

`lowConfidence` 仍可作為 UI 的簡化輸出，但應由上述較細緻的 confidence 聚合而來。這可以在不改壞現有 UX 的前提下，讓內部流程更細緻。

### 4. evaluation 以固定樣本集與核心命中率為第一優先
評估層不追求一開始就完整到 dashboard，而是先固定最重要的三項指標：
- `item_name_hit`
- `amount_hit`
- `total_hit`

每次調整 OCR 候選排序、layout 重建、field extraction 或 heuristics，都應能對固定樣本集重跑這三項指標。相比先做複雜 analytics，這是最小但足夠實用的評估基礎。

### 5. heuristics 放到最後，改成針對已結構化結果的補強
heuristics 仍保留，但角色改變：
- 不再是唯一主流程
- 改為補強欄位缺漏、pairing ambiguous case、特定版型規則
- 若與 layout / field extraction 結果衝突，應先利用 confidence 與 validation 決定是否採信

這個決策能避免未來 parser 規則繼續變得不可控，也符合「先標準化主流程，再做版型補丁」的策略。

## Risks / Trade-offs

- **[資料模型變重]** → 需要新 entities / mapping 層；以內部 model 優先、UI 輸出維持相容，降低一次性改動風險
- **[iOS / Android OCR 幾何能力不一致]** → 先定義統一中介 model，再讓平台各自映射到共同結構
- **[confidence 難以一次精準]** → 第一版可先用 rule-based confidence，後續再逐步校準，不要求一開始就數學上完美
- **[evaluation 樣本不足]** → 先以高價值失敗樣本建立 regression set，避免因資料不足而停滯
- **[heuristics 與 field extraction 重疊]** → 需明確規定 heuristics 僅作補強，不應重新接管整個主流程

## Migration Plan

1. 在 OpenSpec 中先定義 `receipt-document-model` capability 與 `receipt-scanning` 的新增要求
2. 建立新的 receipt layout / field / confidence entities，不直接破壞現有 `ScanResultEntity` 對 UI 的輸出
3. 先以 adapter 方式將新 pipeline 轉回現有掃描結果頁需要的資料，降低 UI 改動範圍
4. 建立固定樣本集與 baseline 指標，作為後續每一步調整的比較基準
5. 在 layout / field extraction 穩定後，再逐步把既有 heuristics 內收成補強規則

## Open Questions

- `receipt document model` 是否需要一開始就保存 token 級 rotation / polygon，還是 bounding box 即可
- `merchant` 的第一版是否只要求單值文字欄位，或要同時保存候選來源 line
- line item 的 confidence 是否需要字段級（name / amount 各自一個）還是 item 級總分先足夠
- 固定樣本集應直接放在 repo 內，還是只先定義格式與流程，資料另行管理
