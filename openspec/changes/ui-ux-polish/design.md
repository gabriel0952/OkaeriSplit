## Context

OkaeriSplit 目前所有載入狀態統一使用 `AppLoadingWidget`（`CircularProgressIndicator`），空狀態呈現方式各頁面不一致（部分有圖示文字，部分無），頁面切換無過場動畫（go_router 預設 fade/material），群組列表使用兩個並排的 `FloatingActionButton`，且缺少使用者操作的微互動回饋。

技術限制：
- Flutter 3.x + Riverpod + go_router
- 不引入新的動畫套件（使用 Flutter 內建 `AnimatedWidget`、`AnimatedSwitcher`、`TweenAnimationBuilder`）
- Shimmer 效果使用 `shimmer` pub package（已常見於 Flutter 生態，或自行實作）

## Goals / Non-Goals

**Goals:**
- 提升各頁面骨架屏的感知載入速度（視覺佔位取代 spinner）
- 統一各頁面空狀態的設計語言（圖示 + 說明 + 行動按鈕）
- 加入輕量的頁面切換過場動畫（slide from right）
- 為新增/刪除消費加入微互動動畫
- 改善群組列表雙 FAB 的操作體驗

**Non-Goals:**
- 不重構現有主題系統（ThemeData）
- 不引入複雜的 Lottie 動畫或大型動畫資源
- 不修改設計 token（色彩、字型大小）

## Decisions

### D1：骨架屏實作方式

**決定**：自行實作 `SkeletonBox` 元件（使用 Flutter 內建漸層動畫），不引入 `shimmer` 套件。

**理由**：`shimmer` 套件會增加依賴，且自訂元件更容易控制動畫速度與色彩主題整合。實作方式為 `AnimatedBuilder` + `LinearGradient` shimmer 流動效果。

**替代方案**：引入 `shimmer` 套件 — 較快實作但增加依賴樹。

---

### D2：空狀態元件設計

**決定**：建立通用 `EmptyStateWidget`，接受 `icon`、`title`、`subtitle`、`action`（可選 `FilledButton.tonal`）參數。

**理由**：各頁面重用同一元件確保視覺一致性，且每個使用點只需傳入文字/圖示即可客製化。

---

### D3：頁面過場動畫

**決定**：在 go_router 的 route 定義中改用 `CustomTransitionPage`，採用 `SlideTransition`（from right）+ `FadeTransition` 組合。

**理由**：符合 iOS/Android 原生導航模式，比預設 Flutter material 頁面切換更流暢自然。
**替代方案**：使用 `go_router_builder` 生成的路由 — 需額外 codegen，過度複雜。

---

### D4：ExpandableFab 實作

**決定**：在 `lib/core/widgets/expandable_fab.dart` 建立獨立元件，接受 `children` 清單（每個子項目為 `ExpandableFabItem(icon, label, onPressed)`）。

**理由**：群組列表目前兩個 FAB 並排於右下角，視覺上佔太多空間且不符合 Material 3 建議。ExpandableFab 點擊後展開，更符合使用習慣。

---

### D5：微互動動畫

**決定**：新增消費成功後，使用 `AnimatedSwitcher` + `ScaleTransition` 在 FAB 上顯示短暫 checkmark；刪除消費使用 `AnimatedList` + `SizeTransition` 滑出效果。

**理由**：`AnimatedList` 已是 Flutter 內建，`ScaleTransition` 無需額外依賴。

## Risks / Trade-offs

- [風險] `AnimatedList` 需要將 `ListView` 替換為 `AnimatedList`，可能影響現有捲動行為 → 僅在 `expense_list_screen` 啟用，其他頁面保留 `ListView`
- [風險] 骨架屏形狀需與實際內容對應，若未來卡片佈局改變需同步更新骨架屏 → 骨架屏使用相對通用的行列佔位形狀，不完全 1:1 對應
- [取捨] 頁面過場動畫若所有 route 都套用，在低端裝置可能有掉幀 → 僅套用至主要 push/pop 路由，modal bottom sheet 保持原樣
