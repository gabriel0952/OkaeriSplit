## ADDED Requirements

### Requirement: 群組設定頁路由
系統 SHALL 提供 `/groups/:groupId/settings` 路由，對應 `GroupSettingsScreen`。

#### Scenario: 從群組主頁進入設定頁
- **WHEN** 使用者點擊群組主頁 AppBar 的設定圖示
- **THEN** 系統 push 至 `/groups/:groupId/settings`

### Requirement: 群組基本資訊顯示與編輯
`GroupSettingsScreen` SHALL 顯示群組名稱、描述、貨幣等基本資訊，並提供編輯入口。

#### Scenario: 顯示群組基本資訊
- **WHEN** 使用者進入群組設定頁
- **THEN** 頁面顯示群組名稱、描述（若有）、使用貨幣

#### Scenario: 編輯群組基本資訊
- **WHEN** 使用者點擊名稱或描述旁的編輯圖示
- **THEN** 系統允許使用者修改並儲存，儲存後立即更新顯示

### Requirement: 成員管理整合至設定頁
`GroupSettingsScreen` SHALL 顯示群組成員列表，並提供邀請新成員與移除成員的功能，功能行為與原 GroupDetailScreen 的成員管理相同。

#### Scenario: 顯示成員列表
- **WHEN** 使用者進入群組設定頁
- **THEN** 頁面顯示所有群組成員（含頭像、顯示名稱）

#### Scenario: 邀請新成員（非封存群組）
- **WHEN** 群組未封存且使用者點擊「邀請成員」或「新增訪客」
- **THEN** 系統顯示對應的邀請對話框（`InviteMemberDialog` / `AddGuestMemberDialog`）

#### Scenario: 封存群組禁止邀請
- **WHEN** 群組已封存
- **THEN** 邀請成員與新增訪客的入口不顯示

#### Scenario: 移除成員（左滑手勢）
- **WHEN** 非 Guest 使用者在設定頁成員列表向左滑某位成員
- **THEN** 系統顯示確認對話框，確認後移除該成員

### Requirement: 結算與統計快捷入口
`GroupSettingsScreen` SHALL 提供進入結算頁與統計頁的快捷入口。

#### Scenario: 進入結算頁
- **WHEN** 使用者點擊設定頁的「結算」入口
- **THEN** 系統導航至 `/groups/:groupId/balances`

#### Scenario: 進入統計頁
- **WHEN** 使用者點擊設定頁的「統計」入口
- **THEN** 系統導航至 `/groups/:groupId/stats`

### Requirement: 分享群組連結
`GroupSettingsScreen` SHALL 提供分享群組邀請連結的功能，行為與原 GroupDetailScreen 的分享功能相同。

#### Scenario: 點擊分享
- **WHEN** 使用者點擊分享按鈕
- **THEN** 系統產生並分享群組邀請連結

### Requirement: 離開群組
`GroupSettingsScreen` SHALL 提供「離開群組」功能（非擁有者可見）。

#### Scenario: 離開群組
- **WHEN** 非群組擁有者的使用者點擊「離開群組」
- **THEN** 系統顯示確認對話框，確認後執行離開並返回群組列表

### Requirement: 刪除群組
`GroupSettingsScreen` SHALL 提供「刪除群組」功能（僅群組擁有者可見）。

#### Scenario: 刪除群組
- **WHEN** 群組擁有者點擊「刪除群組」
- **THEN** 系統顯示確認對話框，確認後刪除群組並返回群組列表

### Requirement: Guest 不可見管理操作
當使用者為 Guest 身份時，設定頁的成員邀請、移除、刪除群組等管理操作 SHALL 隱藏或禁用。

#### Scenario: Guest 進入設定頁
- **WHEN** 以訪客身份進入群組設定頁
- **THEN** 邀請成員、移除成員、刪除群組等操作不顯示
