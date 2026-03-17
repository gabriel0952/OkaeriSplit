### Requirement: 使用者可從群組詳情頁建立分享連結
GroupDetailScreen 的 AppBar 中 SHALL 顯示一個分享圖示按鈕（share icon）。
點擊後系統 SHALL 呼叫 Supabase RPC `create_share_link`，取得 share token 後組合成完整 URL，並透過 `share_plus` 開啟系統分享 sheet。

#### Scenario: 成功建立並分享連結
- **WHEN** 使用者在 GroupDetailScreen 點擊 AppBar 分享按鈕
- **THEN** 系統呼叫 `create_share_link` RPC 取得 token，組成 `https://<domain>/s/<token>` 並開啟系統分享 sheet

#### Scenario: 建立連結期間顯示 loading
- **WHEN** `create_share_link` RPC 呼叫進行中
- **THEN** 分享按鈕 SHALL 顯示 loading 狀態（或停用），防止重複點擊

#### Scenario: 建立連結失敗
- **WHEN** `create_share_link` RPC 回傳錯誤
- **THEN** 系統 SHALL 顯示錯誤 snackbar，不開啟分享 sheet

### Requirement: 後端建立 share token 並儲存
Supabase RPC `create_share_link(p_group_id UUID)` SHALL 以 `SECURITY DEFINER` 執行：
1. 驗證呼叫者（`auth.uid()`）為該群組成員
2. 產生 128-bit random token（`encode(gen_random_bytes(16), 'hex')`）
3. 插入 `share_links` table（token、group_id、created_by、expires_at = NOW() + 3 months）
4. 回傳 token 字串

#### Scenario: 群組成員成功建立 token
- **WHEN** 已驗證的群組成員呼叫 `create_share_link`
- **THEN** RPC 插入一筆 share_links 記錄並回傳新 token

#### Scenario: 非群組成員嘗試建立 token
- **WHEN** 非群組成員呼叫 `create_share_link(p_group_id)`
- **THEN** RPC SHALL 回傳錯誤（拒絕建立）

#### Scenario: 同一群組可建立多個 token
- **WHEN** 使用者多次點擊分享按鈕
- **THEN** 每次呼叫 SHALL 產生新的獨立 token（舊 token 仍有效）

### Requirement: share_links 資料表結構
`share_links` table SHALL 包含欄位：
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `token` TEXT UNIQUE NOT NULL
- `group_id` UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE
- `created_by` UUID NOT NULL REFERENCES profiles(id)
- `expires_at` TIMESTAMPTZ NOT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()

#### Scenario: Token 過期後不可使用
- **WHEN** 網頁端以過期 token 查詢
- **THEN** 系統 SHALL 回傳 token 無效（RLS 不允許讀取）
