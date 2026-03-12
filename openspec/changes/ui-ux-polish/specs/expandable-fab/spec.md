## ADDED Requirements

### Requirement: ExpandableFab 元件
系統 SHALL 提供 `ExpandableFab` Widget，取代群組列表頁面的雙 FAB。`ExpandableFab` 包含：
- 一個主 FAB（顯示 `add` 圖示，展開後旋轉至 `close`）
- 點擊後從下方展開 2 個子項目（`ExpandableFabChild`），每個子項目含圖示與文字標籤
- 展開/收合使用 `AnimatedContainer` + `FadeTransition`，動畫時長 200ms

`ExpandableFabChild` 接受 `icon`、`label`、`onPressed` 參數。

#### Scenario: 點擊主 FAB 展開
- **WHEN** 使用者點擊群組列表頁右下角的 FAB
- **THEN** 從下方展開兩個子按鈕：「加入群組」（icon: `group_add_outlined`）和「建立群組」（icon: `add`），同時主 FAB 圖示旋轉至 close

#### Scenario: 點擊子項目
- **WHEN** 使用者點擊任一子項目
- **THEN** ExpandableFab 收合，執行對應動作（加入/建立群組）

#### Scenario: 點擊遮罩收合
- **WHEN** ExpandableFab 展開時，使用者點擊其他區域
- **THEN** ExpandableFab 收合，不執行任何動作

---

### Requirement: 群組列表使用 ExpandableFab
群組列表頁面 SHALL 改用 `ExpandableFab` 取代目前的兩個並排 `FloatingActionButton`。

#### Scenario: 群組列表 FAB 顯示
- **WHEN** 使用者開啟群組列表頁
- **THEN** 右下角顯示單一 FAB（`add` 圖示），而非兩個並排 FAB
