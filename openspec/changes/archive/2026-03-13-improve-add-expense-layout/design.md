## Context

`add_expense_screen.dart`（1269 行）是 OkaeriSplit 核心頁面，使用 `ListView` + `Form` 作為主容器。目前在 iPhone SE（320pt 寬）等小螢幕裝置上，`Row` 內的欄位組合（金額 + 幣別、付款人 + 日期）因為固定 flex 比例導致溢出或文字截斷。此外提交按鈕在某些 Android 裝置上會被底部導覽列遮蔽。

## Goals / Non-Goals

**Goals:**
- 修正 `Row` 欄位在窄螢幕（≥ 320pt）溢出問題
- 表單 padding 根據螢幕寬度自適應
- 提交按鈕固定於 SafeArea 底部，不被系統列遮蔽
- `Wrap` 元件（分帳方式、分類）確保換行間距正常
- 不改變任何功能邏輯或資料流

**Non-Goals:**
- 不支援平板大螢幕（≥ 768pt）的橫排雙欄布局
- 不修改任何 Provider / Repository / domain 層
- 不更換狀態管理方式

## Decisions

### 1. 使用 `MediaQuery.sizeOf(context).width` 計算響應式值

**決定**：在 `build()` 取得螢幕寬度，透過工具函式回傳對應的 padding / font scale。

**替代方案**：使用第三方套件（`responsive_framework`）— 拒絕，過度引入依賴。

**理由**：Flutter 原生 API 足夠，且符合「最小變更」原則。

---

### 2. 金額 + 幣別列改為 `IntrinsicWidth` + 固定最小寬度

**決定**：幣別 `DropdownButton` 改以 `ConstrainedBox(constraints: BoxConstraints(minWidth: 80))` 包裹，金額欄用 `Expanded` 填滿剩餘空間。

**替代方案**：改為兩列垂直排列 — 拒絕，會增加頁面高度。

**理由**：幣別選單文字最長 3 個字元（如 "JPY"），80pt 足夠，金額欄 Expanded 自然填充。

---

### 3. 付款人 + 日期列改為 `Flexible` + `overflow: TextOverflow.ellipsis`

**決定**：兩欄各用 `Flexible(flex: 1)`，內部 text 設 `overflow: ellipsis`，避免長名稱破版。

**理由**：兩欄等分是最直覺的視覺比例，overflow 防止極端情況。

---

### 4. 提交按鈕移至 `Scaffold.bottomNavigationBar` 位置，包裹 `SafeArea`

**決定**：將提交按鈕從 `ListView` 末尾移到 `bottomNavigationBar: SafeArea(child: Padding(..., child: FilledButton(...)))` 。

**替代方案**：保留在 ListView 末尾但加 `resizeToAvoidBottomInset: true` — 已是預設，問題在於底部系統列不屬於鍵盤，`resizeToAvoidBottomInset` 無法處理。

**理由**：`SafeArea` 自動處理 Home Indicator / 導覽列的安全區域，且按鈕固定在底部符合 Material 3 設計模式。

---

### 5. 響應式 padding helper

```dart
EdgeInsets _formPadding(double width) {
  if (width < 360) return const EdgeInsets.all(12);
  if (width < 600) return const EdgeInsets.all(16);
  return const EdgeInsets.all(24);
}
```

## Risks / Trade-offs

- **[風險] 提交按鈕移位** → 若頁面已有 `bottomNavigationBar` 設定需確認衝突；提前讀取檔案確認。
- **[風險] SafeArea 在 Android 手勢模式下行為不同** → 使用 `MediaQuery.of(context).padding.bottom` 作為備援。
- **[Trade-off] 固定底部按鈕遮蓋最後一個欄位** → 在 `ListView` 末尾加 `SizedBox(height: 80)` 確保內容可滾動到按鈕上方。
