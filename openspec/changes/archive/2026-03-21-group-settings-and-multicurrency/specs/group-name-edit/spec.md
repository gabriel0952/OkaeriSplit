# Spec — group-name-edit

## ADDED Requirements

### Requirement: 群組名稱可由成員編輯
非 guest 身份的群組成員可修改群組名稱。

#### Scenario: 成員點擊編輯 icon 修改名稱
- **WHEN** 使用者在群組設定頁點擊名稱旁的編輯 icon
- **THEN** 顯示包含目前名稱的 AlertDialog（TextField + 確認/取消）

#### Scenario: 輸入合法名稱後確認
- **WHEN** 使用者輸入非空名稱並點擊確認
- **THEN** 名稱更新至 Supabase，並重新整理群組資料

#### Scenario: 輸入空名稱
- **WHEN** 使用者清空名稱欄位並點擊確認
- **THEN** 顯示錯誤提示，不送出更新

#### Scenario: Guest 身份
- **WHEN** 使用者以 guest 身份檢視群組設定
- **THEN** 不顯示編輯 icon
