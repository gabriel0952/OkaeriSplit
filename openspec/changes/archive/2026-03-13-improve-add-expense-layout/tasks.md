## 1. 準備工作

- [x] 1.1 閱讀 `add_expense_screen.dart` 確認提交按鈕目前位置及是否已有 `bottomNavigationBar`
- [x] 1.2 確認 `category_picker.dart` 的 `Wrap` 是否也需要調整間距（已有 spacing:8, runSpacing:8，無需修改）

## 2. 響應式 Padding Helper

- [x] 2.1 在 `add_expense_screen.dart` 的 `_AddExpenseScreenState` 內新增 `_formPadding(double width)` 私有方法
- [x] 2.2 將 `ListView` 的 `padding: EdgeInsets.all(16)` 改為呼叫 `_formPadding(MediaQuery.sizeOf(context).width)`

## 3. 金額 + 幣別列修正

- [x] 3.1 找到金額與幣別的 `Row`，確認目前 flex 設定（金額 flex:3，幣別 flex:2）
- [x] 3.2 金額欄保留 `Expanded`，幣別欄改用 `ConstrainedBox(constraints: BoxConstraints(minWidth: 80))` 包裹

## 4. 付款人 + 日期列修正

- [x] 4.1 找到付款人與日期的 `Row`，確認目前 flex 設定（兩欄均已使用等寬 Expanded）
- [x] 4.2 兩欄均已使用 `Expanded`（等效 Flexible flex:1 tight），無需修改
- [x] 4.3 付款人欄 DropdownButton items 已有 `overflow: TextOverflow.ellipsis`，無需修改

## 5. 提交按鈕移至固定底部

- [x] 5.1 將提交按鈕從 `ListView` 的 `children` 末尾移除
- [x] 5.2 改以 `Column([Expanded(Form(ListView)), SafeArea(Padding(button))])` 結構固定於底部
- [x] 5.3 在 `ListView` 的 `children` 末尾加入 `SizedBox(height: 80)` 確保內容可滾動至按鈕上方

## 6. 分帳方式 Wrap 間距

- [x] 6.1 找到分帳方式選擇的 `Wrap`，將 `spacing: 6, runSpacing: 6` 更新為 `spacing: 8, runSpacing: 8`
- [x] 6.2 附件預覽 Wrap 由 `_buildAttachmentSection` 內部管理，category_picker 已有正確設定

