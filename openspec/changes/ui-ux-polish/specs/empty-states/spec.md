## ADDED Requirements

### Requirement: EmptyStateWidget 通用元件
系統 SHALL 提供 `EmptyStateWidget`，接受以下參數：
- `icon`: `IconData`（必填）
- `title`: `String`（必填）
- `subtitle`: `String?`（選填）
- `action`: `Widget?`（選填，通常為 `FilledButton.tonal`）

呈現方式：垂直居中，圖示大小 64，圖示色為 `colorScheme.onSurfaceVariant.withOpacity(0.45)`，title 使用 `titleMedium`，subtitle 使用 `bodyMedium` 加 `onSurfaceVariant` 色。

#### Scenario: 無消費紀錄
- **WHEN** 群組消費列表資料為空
- **THEN** 顯示 `EmptyStateWidget`，圖示為 `receipt_long_outlined`，title 為「尚無消費紀錄」，subtitle 為「點擊 + 新增第一筆消費」

#### Scenario: 無群組
- **WHEN** 使用者沒有任何群組
- **THEN** 顯示 `EmptyStateWidget`，圖示為 `group_outlined`，title 為「還沒有群組」，subtitle 為「建立或加入一個群組開始分帳吧」，action 為「建立群組」按鈕

#### Scenario: 結算歷史為空
- **WHEN** 結算歷史列表為空
- **THEN** 顯示 `EmptyStateWidget`，圖示為 `handshake_outlined`，title 為「尚無結算紀錄」

#### Scenario: 餘額皆為零
- **WHEN** 群組所有成員餘額皆為 0
- **THEN** 顯示 `EmptyStateWidget`，圖示為 `check_circle_outlined`，title 為「帳目已清空」，subtitle 為「群組內沒有未清的帳款」

---

### Requirement: 空狀態行動按鈕
當 `EmptyStateWidget` 的 `action` 有傳入時，SHALL 在 subtitle 下方顯示該按鈕，按鈕與 subtitle 間距為 24px。

#### Scenario: 空狀態有行動按鈕
- **WHEN** `EmptyStateWidget` 傳入 action Widget
- **THEN** 按鈕顯示於說明文字下方 24px 處
