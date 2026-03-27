## Context

OkaeriSplit 目前使用 Material 3 預設主題（主色 #6C63FF），整體視覺無個性。新增消費畫面（`add_expense_screen.dart`，1269 行）在同一個捲動頁面上呈現所有欄位，視覺過載。PRD 設計原則「≤ 3 步完成」未達成，需要重構 UI 佈局與視覺系統。

此次變更為純 UI 層重構：**業務邏輯、狀態管理、API 呼叫、資料流完全不動**，只改 Widget 呈現方式與 Theme 設定。

## Goals / Non-Goals

**Goals:**
- 全域 Theme 升級至 Apple 冷白系視覺語言
- 新增消費畫面改為 Progressive Disclosure，常用路徑縮至 3 步
- 頭像 Chip 取代 Dropdown/CheckboxListTile，視覺更直覺
- 分帳方式折疊後仍可清楚看到目前設定（header 摘要）
- 編輯模式有備註/附件時「更多選項」自動展開

**Non-Goals:**
- 業務邏輯、分帳計算不變
- 不新增任何功能或欄位
- 不改路由結構
- 不新增套件依賴
- 不修改 DB schema 或 API

## Decisions

### D1: Theme 色彩：Indigo #4F46E5，背景 #F5F5F7

**選擇**：Apple 冷白系（底色 #F5F5F7、卡片白色、主色 Indigo）

**拒絕的替代方案**：
- 暖橘深色系（Orix 參考圖）—— 深色背景長時間記帳容易視覺疲勞
- Teal/Emerald 主色 —— 財務語義較弱，Indigo 更有科技感

**理由**：Apple 系底色搭配無陰影卡片是目前 iOS app 主流設計語言，與「簡潔直覺」的產品定位吻合。

### D2: 無 box-shadow，靠背景色差建立層次

**選擇**：`elevation: 0`，底色 #F5F5F7 → 卡片白色，自然產生浮起感

**拒絕的替代方案**：保留 Material 預設陰影 —— 陰影在 Apple 風格中顯得過重

### D3: 金額輸入改為「Display + 隱藏 TextField」模式

**選擇**：`GestureDetector` 包裹金額 Text，點擊 focus 到螢幕外的隱藏 `TextField`，`InputFormatter` 限制輸入

**拒絕的替代方案**：
- 數字鍵盤 Widget（自製）—— 不必要的複雜度，系統鍵盤體驗更好
- 直接用大型 TextFormField —— 無法達到計算機式視覺效果

**理由**：保留系統鍵盤（autofill、輔助功能支援），同時達到大字顯示的視覺效果。

### D4: 分類選擇器改為橫向 ListView tile（60×64px）

**選擇**：水平可滑動 `ListView.builder`，tile 為圓角正方形 icon+label

**拒絕的替代方案**：Wrap chips 橫向滑動 —— chips 高度不夠，視覺辨識度低

**理由**：正方形 tile 視覺面積大、icon 清晰、選取狀態明確，橫向滑動省垂直空間。

### D5: 付款人/成員選擇改為頭像 Chip

**選擇**：`CircleAvatar` + 名字的 Chip，付款人單選、分攤成員多選

**拒絕的替代方案**：
- `DropdownButton`（付款人）—— 視覺資訊量低，不直覺
- `CheckboxListTile`（成員）—— 每行佔高度，4人群組就有4行，壓迫感強

**理由**：頭像 Chip 緊湊、視覺直覺，一眼看出選誰，符合分帳 app 的使用情境。

### D6: 分帳方式 ExpansionTile，折疊 header 顯示摘要

**選擇**：`ExpansionTile`，折疊時 subtitle 顯示「均分」/「自訂比例 (2:1:1)」/「指定金額」

**理由**：確保用戶折疊後仍能看到目前設定，避免「我以為是均分但其實是自訂比例」的操作錯誤。

### D7: 日期/備註/附件移入 ExpansionTile「更多選項」

**選擇**：三者共用一個 `ExpansionTile`；編輯模式且有資料時 `initiallyExpanded: true`

**理由**：此三項在新增時大多數情況使用預設（今天/空/無），收折後大幅降低表單高度。編輯模式自動展開確保已存資料不會被隱藏。

## Risks / Trade-offs

- **[Risk] 金額 Display 模式在某些裝置上 focus 行為不一致** → 使用 `WidgetsBinding.instance.addPostFrameCallback` 延後 focus，並加上 `autofocus: true` 於隱藏 TextField
- **[Risk] 分類橫向 ListView 在分類數量多時右側「+自訂」可能被遮擋** → 使用 `Row` 固定右側按鈕，`Expanded` 包裹 ListView，不受滑動影響
- **[Risk] ExpansionTile 的 `initiallyExpanded` 在 StatefulWidget rebuild 時重置** → 用 `bool _moreOptionsExpanded` state 變數手動控制展開，不依賴 `initiallyExpanded`
- **[Trade-off] 分帳方式收折增加了操作步驟**（需展開才能改） → 以折疊 header 摘要補償，讓用戶知道目前設定而不需展開確認

## Migration Plan

1. 更新 `app_theme.dart`（Light + Dark）
2. 更新 `main_shell.dart` NavigationBar
3. 更新各卡片 widget（非破壞性，只改視覺）
4. 重構 `add_expense_screen.dart` UI（保留所有 state 與邏輯方法）
5. 更新 `category_picker.dart`（新增橫向 ListView 模式）
6. `flutter analyze` 零錯誤確認
7. 既有測試全過確認（業務邏輯不變，不需新增測試）

**Rollback**：純 UI 變更，git revert 即可，無 DB migration。

## Open Questions

（無，設計已與用戶確認完畢）
