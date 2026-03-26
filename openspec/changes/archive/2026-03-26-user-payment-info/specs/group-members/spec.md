## MODIFIED Requirements

### Requirement: 群組設定成員列表支援點擊查看詳情
群組設定頁的成員列表 SHALL 支援點擊互動，點擊任意成員開啟 MemberDetailSheet，顯示該成員的信箱、匯款資訊（若有）及可用操作。現有的 Dismissible swipe-to-dismiss 刪除功能 SHALL 移除，刪除操作整合至 MemberDetailSheet 內。

#### Scenario: 點擊成員開啟詳情 Sheet
- **WHEN** 使用者在群組設定成員列表點擊任意成員
- **THEN** 系統開啟 MemberDetailSheet，顯示該成員頭像、名稱、信箱

#### Scenario: Sheet 顯示匯款資訊
- **WHEN** MemberDetailSheet 開啟，且該成員已設定 payment_info
- **THEN** Sheet 顯示銀行名稱、分行（若有）、帳號、戶名，以及「複製帳號」按鈕

#### Scenario: Sheet 不顯示未設定的匯款資訊
- **WHEN** MemberDetailSheet 開啟，且該成員未設定 payment_info
- **THEN** Sheet 顯示「對方尚未設定匯款資訊」提示文字

#### Scenario: 複製成員信箱
- **WHEN** 使用者在 MemberDetailSheet 點擊信箱旁的複製按鈕
- **THEN** 系統將信箱複製至剪貼簿並顯示 SnackBar「信箱已複製」

#### Scenario: 複製匯款帳號
- **WHEN** 使用者在 MemberDetailSheet 點擊「複製帳號」
- **THEN** 系統將帳號複製至剪貼簿並顯示 SnackBar「帳號已複製」

#### Scenario: 群主可從 Sheet 移除成員
- **WHEN** 目前使用者為群主，且所選成員非自己、非群主，且群組未封存
- **THEN** MemberDetailSheet 底部顯示「移除成員」按鈕（error 色）

#### Scenario: 點擊移除成員觸發確認 dialog
- **WHEN** 群主在 MemberDetailSheet 點擊「移除成員」
- **THEN** 系統顯示確認 dialog，確認後執行移除並關閉 Sheet

#### Scenario: 非群主或自己不顯示移除按鈕
- **WHEN** 目前使用者非群主，或所選成員為自己或群主
- **THEN** MemberDetailSheet 不顯示「移除成員」按鈕
