## Why

目前 OkaeriSplit 功能完整、離線可用，但各頁面的載入狀態、空白狀態、動畫回饋仍使用最基礎的實作（`CircularProgressIndicator`、無動畫），整體視覺質感與精緻度有提升空間。上架後為了吸引使用者留存並建立品牌印象，需要在視覺層面進行一輪系統性精修。

## What Changes

- 將全域 `AppLoadingWidget` 升級為骨架屏（Shimmer Skeleton），針對消費列表、群組列表、餘額頁分別實作對應形狀的骨架
- 統一並優化各頁面的空狀態（Empty State）：加入插畫圖示、說明文字、行動按鈕，且各頁面配置一致
- 為頁面切換加入平滑過場動畫（go_router 自訂 `CustomTransitionPage`）
- 新增微互動動畫：新增消費成功後的確認動畫（checkmark bounce）、刪除消費時的滑出動畫
- 優化 FAB 在群組列表的呈現：改為展開/收合的 `ExpandableFab`，避免兩個並排 FAB 視覺凌亂
- 統一 AppBar 風格：所有二級頁面使用 `centerTitle: false` + 適當的 back button label

## Capabilities

### New Capabilities

- `skeleton-loading`: 骨架屏載入佔位元件，取代全域 spinner，提升感知效能
- `empty-states`: 統一的空白狀態元件，含圖示、說明文字、可選行動按鈕
- `page-transitions`: go_router 自訂過場動畫（slide + fade）
- `micro-animations`: 新增/刪除消費的微互動動畫
- `expandable-fab`: 可展開的複合 FAB 元件，取代群組列表的雙 FAB

### Modified Capabilities

## Impact

- `lib/core/widgets/`: 新增 `skeleton_loader.dart`、`empty_state_widget.dart`、`expandable_fab.dart`
- `lib/routing/app_router.dart`: 修改路由過場設定
- `lib/features/expenses/presentation/screens/expense_list_screen.dart`: 使用骨架屏 + 刪除動畫
- `lib/features/groups/presentation/screens/group_list_screen.dart`: 使用骨架屏 + ExpandableFab
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`: 使用骨架屏
- `lib/features/settlements/presentation/screens/balance_screen.dart`: 使用骨架屏 + 空狀態
- 所有 `AppLoadingWidget` 使用點視情況替換為各自的骨架屏
