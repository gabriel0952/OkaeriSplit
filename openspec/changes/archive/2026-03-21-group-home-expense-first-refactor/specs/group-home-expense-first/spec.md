## ADDED Requirements

### Requirement: 群組主頁以消費紀錄為核心
進入群組（`/groups/:groupId`）時，系統 SHALL 直接顯示該群組的消費清單作為主要內容，而非群組詳情或導航卡片。

#### Scenario: 進入群組時直接看到消費清單
- **WHEN** 使用者從群組列表點擊某個群組
- **THEN** 系統導航至 `/groups/:groupId` 並顯示消費清單（`ExpenseListScreen` 功能）

#### Scenario: 消費清單為空時的提示
- **WHEN** 群組尚無任何消費紀錄
- **THEN** 系統顯示空狀態提示，引導使用者點擊 FAB 新增第一筆消費

### Requirement: 群組摘要 Header 固定顯示於消費清單頂部
消費清單頂部 SHALL 顯示群組名稱與結算摘要 Banner，Banner 固定不隨清單滾動消失。

#### Scenario: 顯示群組名稱
- **WHEN** 使用者進入群組主頁
- **THEN** AppBar 或 Header 顯示該群組的名稱

#### Scenario: 顯示結算摘要
- **WHEN** 使用者進入群組主頁且群組有未結算餘額
- **THEN** Header 顯示至多 2 筆最重要的結算資訊（如「你欠 Alice $200」）

#### Scenario: 結算已清零時顯示
- **WHEN** 群組內所有成員餘額為零（已全部結算）
- **THEN** Header 顯示「已結清」或不顯示結算摘要區塊

### Requirement: AppBar 提供設定入口
群組主頁 AppBar SHALL 右側顯示設定圖示（`Icons.settings_outlined` 或類似），點擊後導航至群組設定頁。

#### Scenario: 點擊設定圖示
- **WHEN** 使用者點擊 AppBar 右上角的設定圖示
- **THEN** 系統導航至 `/groups/:groupId/settings`

### Requirement: FAB 快速新增消費
群組主頁 SHALL 顯示 FloatingActionButton，點擊後進入新增消費流程。

#### Scenario: 點擊 FAB
- **WHEN** 使用者點擊右下角 FAB
- **THEN** 系統導航至 `/groups/:groupId/add-expense`

### Requirement: Guest 模式主頁限制
當使用者以訪客身份進入群組主頁時，系統 SHALL 禁止返回操作（與原 GroupDetailScreen 行為一致）。

#### Scenario: Guest 使用者無法返回
- **WHEN** 以訪客身份進入群組主頁
- **THEN** 返回手勢 / 返回按鈕被禁用（`PopScope(canPop: false)`）
