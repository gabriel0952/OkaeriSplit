## 1. 建立群組頁面重構

- [x] 1.1 將 `CreateGroupScreen` body 改為 `Column(children: [Expanded(SingleChildScrollView), submitBar])`，移除原本的 `SingleChildScrollView` 直接包 `Form`
- [x] 1.2 將群組名稱 `TextFormField` 包入 `Card`，加上適當的 `Padding`（horizontal 16, vertical 4）
- [x] 1.3 將群組類型選擇（`SegmentedButton`）包入 `Card`，Card 上方加 section 標籤 `Text('群組類型', style: titleSmall)`
- [x] 1.4 將幣別選擇改為 Card 內 `ListTile`（trailing: Icon + Text 顯示目前幣別），點擊呼叫 `_showCurrencyPicker` bottom sheet
- [x] 1.5 實作 `_showCurrencyPicker` bottom sheet，列出 `_currencies` 清單，選中後更新 `_selectedCurrency`
- [x] 1.6 實作固定底部 `_buildSubmitBar()`：`SafeArea(child: Padding(horizontal 16, vertical 12, child: FilledButton(...)))`，並將錯誤訊息移至此區上方顯示
- [x] 1.7 移除原本夾在表單中的 `ElevatedButton` 與 `_errorMessage` 顯示，確認 form validation 仍正常運作

## 2. 消費紀錄篩選區塊重構

- [x] 2.1 將 `_FilterSection` 內的搜尋 `TextField` 包入 `Card(child: Padding(...))`，移除 `inputBorder`/`inputTheme` 相關覆寫（使用 theme 預設）
- [x] 2.2 將分類 `FilterChip` 群組包入 `Card`，維持水平捲動的 `SingleChildScrollView`，Card 內加 `horizontal 16, vertical 10` padding
- [x] 2.3 將付款人 `DropdownButton` 與日期範圍 `InkWell` 包入同一個 `Card`（`Row` 保持不變）
- [x] 2.4 調整各 Card 之間間距為 `SizedBox(height: 8)`，整體 `_FilterSection` container padding 調整為 `fromLTRB(16, 8, 16, 12)`
- [x] 2.5 確認「清除所有篩選」按鈕仍正確顯示於最下方，且 `hasActiveFilters` 邏輯不受影響
