## ADDED Requirements

### Requirement: 訪客可從群組頁進入帳號升級流程
GroupDetailScreen AppBar SHALL 在訪客模式下提供進入「建立正式帳號」的入口。

#### Scenario: 訪客進入升級畫面
- **WHEN** 訪客點擊「建立正式帳號」入口
- **THEN** app 導向 `GuestUpgradeScreen`

### Requirement: 訪客填寫 email、密碼與顯示名稱完成升級
GuestUpgradeScreen SHALL 提供 email、密碼（最少 8 字元）及顯示名稱三個欄位，提交後呼叫 `upgrade_guest_account` Edge Function 完成升級。

#### Scenario: 成功升級
- **WHEN** 訪客輸入合法 email、密碼與顯示名稱，並提交
- **THEN** Edge Function 更新 auth user 與 profile，app refreshSession，`isGuest` 旗標變為 false，導向 `/dashboard`

#### Scenario: email 已被其他帳號使用
- **WHEN** 訪客輸入的 email 已存在於系統中
- **THEN** Edge Function 回傳 409，畫面顯示「此 email 已被其他帳號使用」錯誤訊息

#### Scenario: 密碼不符最低長度
- **WHEN** 訪客輸入的密碼少於 8 個字元並提交
- **THEN** 前端驗證顯示「密碼至少需要 8 個字元」，不送出請求

### Requirement: 升級後解鎖完整 app 功能
升級成功後，前使用者 SHALL 能存取 Dashboard、Profile 與所有群組功能，與正式帳號完全相同。

#### Scenario: 升級後存取 Dashboard
- **WHEN** 訪客升級成功並被導向 `/dashboard`
- **THEN** 底部導航顯示全部分頁（Dashboard、群組、Profile），不再有「訪客模式無法使用」限制

### Requirement: 升級後保留群組成員身份與歷史紀錄
升級過程 SHALL NOT 刪除或重建 `group_members` 記錄，原帳號的所有支出與結算歷史仍與同一 user_id 關聯。

#### Scenario: 升級後查看群組帳目
- **WHEN** 訪客升級成功後進入原群組
- **THEN** 所有支出、分帳、結算紀錄完整保留，顯示與升級前相同
