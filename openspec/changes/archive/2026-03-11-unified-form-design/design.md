## Context

AddExpenseScreen 在 Milestone 7 UI 翻新後採用了三層佈局：
1. **全寬金額區**（頂部 Container）
2. **分區 Card**（描述/分類、付款人、分帳方式、更多選項）
3. **固定底部提交按鈕**（`SafeArea` + `FilledButton`）

`CreateGroupScreen` 與 `_FilterSection` 目前是舊設計：扁平 Column 欄位 + 全版面卷動，提交按鈕夾在欄位之間。

## Goals / Non-Goals

**Goals:**
- `CreateGroupScreen` 改為分區 Card 佈局 + 固定底部按鈕
- `_FilterSection` 改為 Card 分組，各控制項有明確視覺分區
- 所有表單沿用同一套 spacing / typography token（`titleSmall` section label、`12px` card gap、`16px` card padding）

**Non-Goals:**
- 不修改業務邏輯或 Riverpod provider
- 不新增欄位或功能
- 不改動 AppTheme token（已有統一 `filledButtonTheme`、`cardTheme`、`inputDecorationTheme`）

## Decisions

### D1：CreateGroupScreen 佈局結構

採用 AddExpenseScreen 的模式：
```
Scaffold
  body: Column
    Expanded > SingleChildScrollView > Column(padding 16)
      Card [群組資訊]       ← 群組名稱 TextField
      SizedBox(12)
      Section label: '群組類型'
      Card [類型選擇]       ← SegmentedButton
      SizedBox(12)
      Section label: '幣別'
      Card [幣別選擇]       ← DropdownButtonFormField / ListTile-style picker
    _buildSubmitBar()      ← SafeArea + FilledButton (fixed bottom)
```

優於舊設計：section label 讓欄位語意清晰；固定底部按鈕符合 iOS/Android 的 CTA 慣例。

### D2：幣別選擇改為 Card 內 ListTile picker

`DropdownButtonFormField` 在 Card 內會有視覺不一致（下拉箭頭與 Card 圓角衝突）。改為 Card 內 `ListTile` + `trailing: Text(currency)` + `onTap` 開啟 `showModalBottomSheet`，與 AddExpenseScreen 的幣別選取一致。

### D3：_FilterSection 保留抽屜式收折，改 Card 包裹

篩選區塊維持「點擊篩選按鈕展開/收折」的互動，內部改為：
```
Container(color: surfaceContainerLow)
  Column
    Card [關鍵字搜尋]       ← TextField
    SizedBox(8)
    Card [分類篩選]         ← 水平 chip 列（若有資料才顯示）
    SizedBox(8)
    Card [付款人 + 日期範圍] ← Row of two InputDecorator
```

避免在篩選欄位間維持 surfaceContainerLow 的整塊底色，改為卡片讓各篩選組件有視覺層次。

## Risks / Trade-offs

- **幣別改為 ListTile picker**：需新增 bottom sheet 邏輯，比 DropdownButtonFormField 略多程式碼 → 可參考 AddExpenseScreen `_showCurrencyPicker` 複用模式
- **_FilterSection Card 化**：Cards 有圓角，在篩選區塊展開時高度略增 → 可接受，不影響功能
