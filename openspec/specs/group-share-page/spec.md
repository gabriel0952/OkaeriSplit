### Requirement: 網頁路由 /s/[token] 渲染群組總覽
Next.js 網頁 SHALL 在路由 `/s/[token]` 以 server-side rendering 查詢資料並渲染群組總覽頁面。
頁面完全公開（anon 存取），無需任何登入。

#### Scenario: 有效 token 開啟頁面
- **WHEN** 使用者以瀏覽器開啟 `/s/<valid-token>`
- **THEN** 頁面 SHALL 顯示群組名稱、成員帳務狀態列表、消費清單

#### Scenario: 無效或過期 token
- **WHEN** 使用者以瀏覽器開啟 `/s/<invalid-or-expired-token>`
- **THEN** 頁面 SHALL 顯示「連結無效或已過期」提示，不顯示任何群組資料

### Requirement: 群組總覽頁面顯示成員帳務狀態
頁面 SHALL 列出所有群組成員及其帳務狀態（淨值：應收或應付金額）。
已付款狀態 SHALL 以視覺方式呈現（例如標記），但不提供互動操作（唯讀）。
v1 不顯示轉帳資訊。

#### Scenario: 顯示每位成員的淨帳務金額
- **WHEN** 頁面成功載入
- **THEN** 每位成員旁 SHALL 顯示其淨帳務金額（正數為應收、負數為應付）

#### Scenario: 已結清成員的顯示
- **WHEN** 某成員帳務淨值為 0
- **THEN** 頁面 SHALL 以視覺方式標示該成員已結清

### Requirement: 群組總覽頁面顯示消費清單
頁面 SHALL 列出該群組的所有消費記錄，包含：消費名稱、金額、付款人、消費日期、分類。
消費清單為唯讀，不提供任何操作。

#### Scenario: 顯示消費清單
- **WHEN** 頁面成功載入
- **THEN** 消費列表 SHALL 依消費日期降序顯示所有消費記錄

#### Scenario: 無消費記錄
- **WHEN** 群組尚無任何消費
- **THEN** 頁面 SHALL 顯示空狀態提示（例如「尚無消費記錄」）

### Requirement: RLS 允許 anon 透過有效 token 存取群組資料
Supabase RLS SHALL 允許 anon 角色在 token 有效（存在於 share_links 且未過期）的前提下，
讀取對應群組的 `groups`、`group_members`、`profiles`、`expenses` 資料。

#### Scenario: 有效 token 查詢群組資料
- **WHEN** anon 請求攜帶有效 token 查詢群組資料
- **THEN** Supabase RLS SHALL 允許讀取該群組相關資料

#### Scenario: 無效 token 查詢被拒絕
- **WHEN** anon 請求攜帶無效或過期 token
- **THEN** Supabase RLS SHALL 拒絕讀取，回傳空結果或錯誤

#### Scenario: 不同群組資料隔離
- **WHEN** anon 使用群組 A 的 token 嘗試查詢群組 B 的資料
- **THEN** RLS SHALL 不返回群組 B 的任何資料

### Requirement: 網頁視覺風格與 app 一致
網頁 SHALL 使用 MUI（Material UI）元件，整體配色與排版風格接近 app 的 Material Design 風格。
頁面 SHALL 支援 RWD（響應式設計），在手機與桌機瀏覽器均正常顯示。

#### Scenario: 手機瀏覽器開啟
- **WHEN** 使用者在手機瀏覽器開啟分享頁面
- **THEN** 頁面 SHALL 以單欄佈局正常顯示，不出現水平捲軸
