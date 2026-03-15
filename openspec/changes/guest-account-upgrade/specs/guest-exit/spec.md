## ADDED Requirements

### Requirement: 訪客可主動退出訪客模式
GroupDetailScreen 的 AppBar SHALL 在訪客模式下顯示「退出」按鈕。點擊後顯示確認 dialog，確認後清除 session 與本地快取，導回登入畫面。

#### Scenario: 訪客點擊退出並確認
- **WHEN** 訪客在群組頁點擊退出按鈕，並在確認 dialog 中選擇「退出」
- **THEN** Supabase session 登出、Hive `guest_group_id` 清除，app 導向 `/login`

#### Scenario: 訪客取消退出
- **WHEN** 訪客點擊退出按鈕，但在 dialog 中選擇「取消」
- **THEN** dialog 關閉，留在群組頁，session 不受影響

### Requirement: 退出後訪客代碼仍有效
訪客登出後，其在 Supabase 的帳號 SHALL NOT 被刪除。代碼仍可再次使用，直到群組封存。

#### Scenario: 訪客退出後重新登入
- **WHEN** 訪客退出後，回到登入頁選擇「以訪客身份進入」，輸入相同代碼
- **THEN** 成功重新建立 session，進入同一群組
