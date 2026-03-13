## ADDED Requirements

### Requirement: Owner 可封存群組
群組 owner SHALL 可在 GroupDetailScreen 發起封存操作。系統 SHALL 在封存前檢查是否有未結清欠款，若有則顯示警告 Dialog，但允許 owner 選擇強制封存。

#### Scenario: 無未結清欠款時直接封存
- **WHEN** owner 點擊「封存群組」且群組無未結清欠款
- **THEN** 系統呼叫 `archive_group` Edge Function，成功後群組狀態變為 `archived`，UI 顯示「已封存」badge

#### Scenario: 有未結清欠款時顯示警告
- **WHEN** owner 點擊「封存群組」且群組有未結清欠款
- **THEN** 系統顯示警告 Dialog 列出未結清金額，提供「仍要封存」與「取消」兩個選項

#### Scenario: Owner 選擇強制封存
- **WHEN** owner 在警告 Dialog 中點擊「仍要封存」
- **THEN** 系統執行封存，群組狀態變為 `archived`

### Requirement: 封存時自動清理訪客帳號
`archive_group` Edge Function SHALL 在封存群組時，刪除該群組所有 `is_guest = true` 的成員帳號（auth user + profile，group_members 因 CASCADE 自動刪除）。

#### Scenario: 封存時訪客帳號被刪除
- **WHEN** `archive_group` 被呼叫且群組有訪客成員
- **THEN** 每個訪客的 auth user 被 `admin.deleteUser()` 刪除，profiles 與 group_members 因 CASCADE 一併移除

#### Scenario: 封存時無訪客帳號
- **WHEN** `archive_group` 被呼叫且群組無訪客成員
- **THEN** 封存正常完成，無錯誤

### Requirement: 封存後群組為唯讀
群組狀態為 `archived` 時，系統 SHALL 阻止所有寫入操作（新增消費、邀請成員、結算），DB 層 RLS 與 Flutter UI 雙重防護。

#### Scenario: 封存群組中無法新增消費
- **WHEN** 使用者（含 owner）嘗試在封存群組中新增消費
- **THEN** `AddExpenseScreen` 顯示「此群組已封存，無法新增消費」提示並禁用送出按鈕

#### Scenario: DB 層拒絕封存群組的寫入
- **WHEN** 任何用戶對封存群組執行 INSERT/UPDATE/DELETE（expenses、group_members、settlements）
- **THEN** RLS policy 拒絕操作

### Requirement: Owner 可重新開啟封存群組
群組 owner SHALL 可在封存群組的 GroupDetailScreen 點擊「重新開啟」將群組恢復為 `active`。

#### Scenario: 重新開啟封存群組
- **WHEN** owner 點擊「重新開啟群組」並確認
- **THEN** 群組狀態變回 `active`，所有寫入操作恢復可用

### Requirement: 群組列表區分 active / archived
GroupListScreen SHALL 將封存群組移至「已結束」摺疊區段，與進行中群組視覺分離。

#### Scenario: 封存群組出現在已結束區段
- **WHEN** 使用者開啟群組列表
- **THEN** status = archived 的群組顯示在「已結束」摺疊區段，status = active 的群組在上方正常列表

#### Scenario: 已結束區段可展開收合
- **WHEN** 使用者點擊「已結束」區段標題
- **THEN** 該區段展開 / 收合，顯示或隱藏封存群組列表

### Requirement: 訪客裝置在帳號清理後自動登出
群組封存後，訪客的 auth user 被刪除，訪客裝置上的 session token 隨即失效。Flutter 端 SHALL 偵測到 session 失效（Supabase client 的 `SIGNED_OUT` auth event），並自動導向登入畫面，同時清除 Hive 中儲存的 `guest_group_id`。

#### Scenario: 訪客 app 在背景時群組被封存
- **WHEN** 訪客 app 在背景，群組 owner 執行封存，訪客帳號被刪除
- **THEN** 訪客下次回到 app 並觸發任何 Supabase 請求時，token refresh 失敗，`authStateProvider` 收到 SIGNED_OUT 事件，router 將訪客導回 `/login`

#### Scenario: 訪客 app 在前景時群組被封存
- **WHEN** 訪客 app 在前景瀏覽群組，群組 owner 執行封存，訪客帳號被刪除
- **THEN** 下一次 Supabase 請求回傳 401，client 嘗試 refresh 失敗，觸發 SIGNED_OUT，router 自動導回 `/login`

#### Scenario: guest_group_id 在登出時清除
- **WHEN** 訪客因帳號失效而被登出
- **THEN** `app_router.dart` 的 auth listener 清除 `Hive.box('groups_cache').delete('guest_group_id')`，避免下次進入 app 時誤跳轉到已封存群組

### Requirement: 封存群組的邀請碼失效
群組封存後，`join_group_by_code` RPC SHALL 拒絕以該群組邀請碼加入，防止新成員加入封存群組。

#### Scenario: 使用封存群組邀請碼加入失敗
- **WHEN** 使用者輸入一個已封存群組的邀請碼
- **THEN** 系統回傳「此群組已結束，無法加入」錯誤
