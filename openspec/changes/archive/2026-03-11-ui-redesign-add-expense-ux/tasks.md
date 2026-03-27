## 1. Design System & Theme

- [x] 1.1 更新 `app_theme.dart` Light theme：scaffoldBackgroundColor `#F5F5F7`、CardTheme 白色背景圓角 16px elevation 0
- [x] 1.2 更新 `app_theme.dart` Light theme：AppBar 透明背景、elevation 0、scrolledUnderElevation 0、標題 fontSize 17 fontWeight 600
- [x] 1.3 更新 `app_theme.dart` Light theme：主色改為 `#4F46E5`（Indigo）、ColorScheme 更新對應色彩
- [x] 1.4 更新 `app_theme.dart` Light theme：Typography letterSpacing（titleMedium -0.2、bodyLarge -0.1、titleLarge -0.3）
- [x] 1.5 更新 `app_theme.dart` Light theme：FilledButton 高度 52px 圓角 14px、ChipTheme 無邊框圓角 20px、DividerTheme 細線
- [x] 1.6 更新 `app_theme.dart` Light theme：NavigationBarTheme 白底、indicator 主色 12% opacity、label fontSize 11
- [x] 1.7 同步更新 `app_theme.dart` Dark theme 對應所有設定（底色 `#1C1C1E`、卡片 `#2C2C2E`）

## 2. Shell & 全域元件

- [x] 2.1 更新 `main_shell.dart`：NavigationBar 加上 0.5px 頂部細線 Container 包裹、icon 換為 rounded 系列
- [x] 2.2 更新 `balance_summary_card.dart`：使用 `colorScheme` 正負語義色（hardcoded `Colors.green/red` 換掉）、卡片 padding/排版優化
- [x] 2.3 更新 `expense_card.dart`：卡片圓角、分類色彩 icon、排版改善（移除 hardcoded 顏色）
- [x] 2.4 更新 `group_card.dart`：卡片視覺升級，套用新 theme 樣式

## 3. 新增消費 — [A] 金額區重構

- [x] 3.1 在 `_AddExpenseScreenState` 新增 `_amountFocusNode`，隱藏 TextField 接收輸入（`opacity: 0` 或 offscreen）
- [x] 3.2 實作金額 Display widget：`GestureDetector` → focus，大字 Text（fontSize 48, fontWeight 700），0 時顯示灰色 placeholder
- [x] 3.3 加入 `FilteringTextInputFormatter`：只允許數字與一個小數點、小數點後 ≤ 2 位
- [x] 3.4 幣別 Chip：改為 de-emphasize 樣式（fontSize 13、淺色邊框），置於金額區左上角
- [x] 3.5 整個金額區固定在 Column 頂部（不在 ListView 內，不隨捲動）

## 4. 新增消費 — [B1] 描述 + 分類卡重構

- [x] 4.1 描述 TextField：移除 OutlineInputBorder，改為無邊框樣式，填滿卡片內一整行
- [x] 4.2 更新 `category_picker.dart`：加入 `horizontal` 模式，以橫向 `ListView.builder` 輸出 60×64px tile
- [x] 4.3 分類 tile 樣式：圓角容器，icon 上 + label 下；選中主色填底白字，未選中淺灰底深色字
- [x] 4.4 「+ 自訂」按鈕固定在 Row 右側（`Expanded` 包裹 ListView），不隨分類列表捲動

## 5. 新增消費 — [B2] 付款人卡重構

- [x] 5.1 移除付款人 `DropdownButton`，改為 `Wrap` 包裹頭像 Chip（`CircleAvatar` + 姓名）
- [x] 5.2 頭像 Chip 選中樣式：主色邊框 + ✓ icon badge；未選中：灰色邊框
- [x] 5.3 單選邏輯：點擊 Chip 更新 `_paidBy` state

## 6. 新增消費 — [B3] 分攤卡重構

- [x] 6.1 移除 `CheckboxListTile` 成員列表，改為 `Wrap` 頭像 Chip 多選
- [x] 6.2 選中成員 Chip 樣式：主色填底白字；未選中：淺灰底
- [x] 6.3 最少 1 人限制：只剩 1 人時取消勾選操作無效
- [x] 6.4 即時分攤摘要文字：均分顯示每人金額，非均分顯示對應描述
- [x] 6.5 分帳方式改為 `ExpansionTile`（`_splitTypeExpanded` bool state），預設折疊
- [x] 6.6 `ExpansionTile` 折疊 header subtitle：顯示目前分帳方式摘要（含比例/品項數）
- [x] 6.7 展開內容改為 `RadioListTile` 四選一（均分/自訂比例/指定金額/項目拆分）
- [x] 6.8 選中非均分後，對應輸入 UI 在 RadioListTile 下方 inline 展開（原有輸入邏輯保留）

## 7. 新增消費 — [B4] 更多選項折疊區

- [x] 7.1 新增 `_moreOptionsExpanded` bool state，初始值由編輯模式資料決定
- [x] 7.2 在 `initState` / 資料載入後：若 `note != null || attachmentUrls.isNotEmpty` 則 `_moreOptionsExpanded = true`
- [x] 7.3 日期選擇器移入 ExpansionTile（原有 `showDatePicker` 邏輯保留）
- [x] 7.4 備註 TextField 移入 ExpansionTile
- [x] 7.5 附件區移入 ExpansionTile

## 8. 新增消費 — [C] 固定底部按鈕

- [x] 8.1 將 `FilledButton` 從 ListView 底部移出，固定在 `SafeArea` 底部 Column 中
- [x] 8.2 Disabled 條件：`_amountController.text` 為空或解析後 ≤ 0，**或** `_descriptionController.text.trim()` 為空
- [x] 8.3 整體佈局改為 `Column(children: [amountArea, Expanded(child: ListView(...)), submitButton])`

## 9. 驗收

- [x] 9.1 `flutter analyze` 零警告零錯誤
- [x] 9.2 既有 48 項測試全部通過（業務邏輯未改動）
- [ ] 9.3 新增消費常用路徑驗證：金額 → 描述 → 「新增消費」按鈕 3 步可完成
- [ ] 9.4 編輯模式驗證：有備註/附件時「更多選項」自動展開且資料正確顯示
- [ ] 9.5 分帳方式折疊驗證：切換至自訂比例後折疊，header 顯示「自訂比例 (1:1:1)」
- [ ] 9.6 Light / Dark 模式視覺確認（色彩符合規範）
