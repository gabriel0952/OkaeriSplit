## ADDED Requirements

### Requirement: 封存群組中禁止新增成員
GroupDetailScreen 的邀請成員與新增訪客入口 SHALL 在群組已封存時隱藏。

#### Scenario: 封存群組中邀請按鈕隱藏
- **WHEN** 使用者進入已封存群組的 GroupDetailScreen
- **THEN** 「邀請」與「訪客」按鈕不顯示

### Requirement: 封存後訪客認領代碼失效
群組封存後，現有訪客 claim_code SHALL 因訪客帳號已被刪除而自動失效，`claim_guest_member` Edge Function 回傳「無效的訪客代碼」錯誤。

#### Scenario: 使用已封存群組的訪客代碼
- **WHEN** 使用者輸入已封存群組所屬的訪客代碼
- **THEN** `claim_guest_member` 找不到對應 profile，回傳 404「無效的訪客代碼」
