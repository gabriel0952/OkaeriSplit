## ADDED Requirements

### Requirement: 讀取時自動寫入 Hive 快取
線上讀取群組列表或消費列表成功後，系統 SHALL 將資料序列化為 JSON 並存入對應 Hive Box。

#### Scenario: 群組列表快取更新
- **WHEN** GroupRepositoryImpl 成功從 Supabase 取得群組列表
- **THEN** 將群組列表 JSON 寫入 `groups_cache` box

#### Scenario: 消費列表快取更新（按群組）
- **WHEN** ExpenseRepositoryImpl 成功從 Supabase 取得某群組消費列表
- **THEN** 將消費列表 JSON 以 groupId 為 key 寫入 `expenses_cache` box

#### Scenario: 成員列表快取更新（按群組）
- **WHEN** GroupRepositoryImpl 成功從 Supabase 取得群組成員列表
- **THEN** 將成員列表 JSON 以 groupId 為 key 寫入 `group_members_cache` box

---

### Requirement: 離線時從快取讀取
`isOnline = false` 時，Repository SHALL 從對應 Hive Box 讀取資料回傳 UI。

#### Scenario: 離線讀取群組列表（有快取）
- **WHEN** 無網路且 groups_cache 有資料
- **THEN** 回傳快取的群組列表，UI 正常顯示

#### Scenario: 離線讀取消費列表（有快取）
- **WHEN** 無網路且 expenses_cache 有對應 groupId 的資料
- **THEN** 回傳快取的消費列表，UI 正常顯示

#### Scenario: 離線且無快取
- **WHEN** 無網路且對應 Box 無資料
- **THEN** 回傳空列表，UI 顯示空狀態（不崩潰）

---

### Requirement: 離線新增消費時從快取讀取成員資料
無網路時開啟新增消費畫面，系統 SHALL 從 `group_members_cache` 讀取付款人與分攤成員列表。

#### Scenario: 離線時付款人列表正常顯示
- **WHEN** 無網路且 group_members_cache 有該群組資料
- **THEN** 付款人下拉選單顯示快取的成員列表

#### Scenario: 離線且成員快取為空
- **WHEN** 無網路且 group_members_cache 無資料
- **THEN** 付款人列表顯示空，但不崩潰（使用者看到提示文字）
