## MODIFIED Requirements

### Requirement: 封存群組中禁止新增成員
GroupSettingsScreen 的邀請成員與新增訪客入口 SHALL 在群組已封存時隱藏。

#### Scenario: 封存群組中邀請按鈕隱藏
- **WHEN** 使用者進入已封存群組的 GroupSettingsScreen
- **THEN** 「邀請」與「訪客」按鈕不顯示
