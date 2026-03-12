## ADDED Requirements

### Requirement: 頁面切換過場動畫
所有透過 go_router `push` 進入的二級頁面（如群組詳情、消費詳情、新增消費、個人資料等）SHALL 使用 `SlideTransition`（從右側滑入）+ `FadeTransition` 的組合過場動畫，動畫時長 250ms，曲線使用 `Curves.easeInOut`。

#### Scenario: 進入二級頁面
- **WHEN** 使用者點擊群組卡片進入群組詳情
- **THEN** 新頁面從右側滑入，舊頁面向左淡出，動畫流暢不閃爍

#### Scenario: 返回上一頁
- **WHEN** 使用者點擊返回按鈕
- **THEN** 當前頁面向右滑出，下方頁面淡入，動畫方向與進入時相反

---

### Requirement: Tab 切換不使用過場
根頁面的 Tab 切換（底部導航列）SHALL 不套用 slide 過場動畫，保留 Flutter 預設的即時切換行為。

#### Scenario: 底部 Tab 切換
- **WHEN** 使用者點擊底部導航列的不同 Tab
- **THEN** 頁面即時切換，無滑動動畫
