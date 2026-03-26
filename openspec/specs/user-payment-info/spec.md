### Requirement: 使用者可設定個人匯款資訊
使用者 SHALL 能在「我的」頁面填寫個人匯款資訊，包含銀行名稱（必填）、分行（選填）、帳號（必填）、戶名（必填）。訪客帳號（is_guest = true）SHALL NOT 顯示此功能。

#### Scenario: 開啟編輯 Sheet
- **WHEN** 使用者點擊「我的」頁面的「匯款資訊」ListTile
- **THEN** 系統開啟 EditPaymentInfoSheet，顯示現有資料（若有）

#### Scenario: 成功儲存匯款資訊
- **WHEN** 使用者填寫銀行名稱、帳號、戶名後點擊「儲存」
- **THEN** 系統將資料寫入 profiles.payment_info（JSONB），關閉 Sheet，並更新頁面顯示

#### Scenario: 必填欄位為空時阻止送出
- **WHEN** 使用者未填寫銀行名稱、帳號或戶名，點擊「儲存」
- **THEN** 系統顯示欄位錯誤訊息，不送出請求

#### Scenario: 訪客帳號不顯示匯款資訊設定
- **WHEN** 已登入使用者 is_guest 為 true
- **THEN** 「我的」頁面 SHALL NOT 顯示「匯款資訊」section

### Requirement: 群組成員匯款資訊可在成員詳情 Sheet 查看
群組成員的匯款資訊 SHALL 透過群組設定頁的 MemberDetailSheet 查看。MemberDetailSheet 開啟後 SHALL 顯示該成員的匯款資訊（若有），以及複製帳號功能。詳細互動規格見 group-members spec。
