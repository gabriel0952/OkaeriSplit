## ADDED Requirements

### Requirement: 同名成員顯示額外識別資訊
當群組內有兩位或以上 display_name 完全相同的成員時，系統 SHALL 在名稱後以括號附加 email 前綴（`@` 之前的部分，最多顯示 8 字元）以區分。

#### Scenario: 群組內無同名成員
- **WHEN** 群組成員列表中所有 display_name 皆不重複
- **THEN** 名稱 SHALL 照原樣顯示，不加 email 後綴

#### Scenario: 群組內有兩位同名成員
- **WHEN** 群組成員列表中有兩位 display_name 相同的成員
- **THEN** 兩位成員名稱 SHALL 皆加上各自的 email 前綴，格式為「王小明 (wang123)」

#### Scenario: email 前綴超過 8 字元
- **WHEN** 成員 email 前綴長度超過 8 字元
- **THEN** 顯示前 8 字元，不加省略符號（括號內長度固定）

---

### Requirement: 透過搜尋邀請加入的成員擁有完整群組操作權限
不論成員透過邀請碼或搜尋邀請何種方式加入群組，加入後 SHALL 擁有相同的操作權限（新增/編輯/刪除消費、記錄結算），不需額外輸入邀請碼。

#### Scenario: 搜尋邀請加入後可新增消費
- **WHEN** 使用者透過搜尋邀請方式加入群組後進入群組
- **THEN** 新增消費按鈕 SHALL 可見且可操作，無需再輸入邀請碼

#### Scenario: 邀請碼加入後可新增消費
- **WHEN** 使用者透過邀請碼加入群組後進入群組
- **THEN** 新增消費按鈕 SHALL 可見且可操作（維持現有行為）

#### Scenario: 兩種加入方式的權限一致
- **WHEN** 比較邀請碼加入與搜尋邀請加入的成員可執行的操作
- **THEN** 兩者 SHALL 擁有完全相同的操作入口與功能存取
