## Why

使用者反映 App 整體 UI 太制式單調（基本 Material 3 預設感），且新增消費畫面將所有欄位同時展示，造成視覺過載。PRD 中「新增消費 ≤ 3 步完成」的目標未達成，需要透過視覺翻新與互動重構改善體驗。

## What Changes

- **全域視覺系統升級**：色彩從通用紫改為 Apple 冷白系（Indigo 主色 #4F46E5、底色 #F5F5F7、白色卡片），字距收緊，卡片無陰影改以背景色差呈現層次
- **AppBar 風格**：透明底、無捲動陰影，與頁面底色融合
- **NavigationBar 風格**：白底 + 0.5px 頂線、輕量 indicator
- **新增消費畫面改為 Progressive Disclosure 佈局**：金額大字 Display 固定頂部、描述+分類卡、付款人卡、分攤卡，底部固定送出按鈕
- **金額輸入互動改版**：點擊大字 Display 彈出鍵盤，限制只輸入數字與小數點（≤ 2 位）
- **分類選擇器改版**：由 Wrap chips 改為橫向可滑動 tile 列表（60×64px 正方形）
- **付款人 / 成員選擇改版**：移除 Dropdown 與 CheckboxListTile，改為頭像 Chip（單選/多選）
- **分帳方式改為 ExpansionTile**：預設折疊，折疊 header 顯示目前模式摘要
- **日期、備註、附件移入「更多選項」折疊區**；編輯模式有備註/附件時自動展開
- **幣別 Chip**：保留在金額區左上，視覺 de-emphasize（小字淺色）
- **送出按鈕固定在底部**：不隨表單捲動，金額為 0 或描述空白時 disabled

## Capabilities

### New Capabilities

- `design-system`: App 全域視覺設計語言——色彩規範、字體層級、卡片/形狀/陰影策略
- `add-expense-ux`: 新增消費畫面的互動規格——Progressive Disclosure 佈局、各區塊交互行為

### Modified Capabilities

（無現有 spec 需更新，此次為全新建立）

## Impact

- `app/lib/core/theme/app_theme.dart`：Theme 全面重寫（Light + Dark）
- `app/lib/features/shell/main_shell.dart`：NavigationBar 樣式
- `app/lib/features/expenses/presentation/screens/add_expense_screen.dart`：UI 結構重構（邏輯/業務不變）
- `app/lib/features/expenses/presentation/widgets/category_picker.dart`：改為橫向 ListView tile
- `app/lib/features/dashboard/presentation/widgets/balance_summary_card.dart`：卡片視覺升級
- `app/lib/features/groups/presentation/widgets/group_card.dart`：卡片視覺升級
- `app/lib/features/expenses/presentation/widgets/expense_card.dart`：卡片視覺升級
- 無 DB schema 變更、無 API 變更、無新依賴套件
