## AI — Gemini Vision API

**這是整個專案的核心。** 一張收據照片丟進去，Gemini 回傳完整結構化 JSON：

```
收據照片 → Gemini 2.0 Flash → {
  storeName: "全家便利商店",    // 自動翻譯繁體中文
  storeNameJa: "ファミリーマート", // 保留日文原文
  items: "飯糰, 綠茶",         // 商品翻譯
  itemsJa: "おにぎり, 緑茶",    // 商品原文
  amountJPY: 432,              // 日幣金額
  amountTWD: 90.72,            // 自動換算台幣
  taxType: "内税",              // 辨識日本三種稅制
  category: "餐飲",             // 自動分類
  paymentMethod: "現金",        // 辨識付款方式
  date: "2026-03-01",          // 辨識日期
  region: "名古屋",             // 根據日期自動對應地區
  ...
}
```

### Model Fallback 策略

```typescript
const MODELS = [
  "gemini-2.0-flash-001",  // 穩定版優先
  "gemini-2.0-flash",      // 最新版備援
  "gemini-1.5-flash",      // 最終 fallback
];
```

### Prompt Engineering 重點

Gemini prompt 是這個專案最花時間的部分（~143 行），關鍵挑戰：

- **日本三種稅制**：外税（價格不含稅）、内税（價格含稅）、免税（退稅），計算邏輯不同
- **折扣格式**：割引、値引、各種日文折扣寫法
- **多稅率**：同一張收據可能有 8%（食品）和 10%（非食品）兩種稅率
- **金額驗證**：要求 Gemini 自行驗算，避免 hallucination

### Schema

| 欄位 | 類型 | 說明 |
|:-----|:-----|:-----|
| 項目 | Title | 商品名稱（繁中） |
| 商店名稱 | Rich Text | 店名（繁中） |
| 商店日文 | Rich Text | 店名（日文原文） |
| 商品日文 | Rich Text | 商品（日文原文） |
| 日期 | Date | 消費日期 |
| 金額 (JPY) | Number | 日幣金額 |
| 金額 (TWD) | Formula | 台幣金額（自動換算） |
| 類別 | Select | 餐飲 / 交通 / 購物 / 門票 / 住宿 / 藥品 / 其他 |
| 支付方式 | Select | 現金 / 信用卡 / Suica / PayPay / 其他 |
| 地區 | Select | 名古屋 / 靜岡 / 松本 / 高山 / 金澤 |
| 用戶 | Rich Text | 記帳人 |
| 備註 | Rich Text | 稅制、折扣資訊 |