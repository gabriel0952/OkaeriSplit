## MODIFIED Requirements

### Requirement: 離線時付款人與分攤成員從快取讀取
無網路狀態下進入新增消費畫面，系統 SHALL 從 `group_members_cache` 讀取成員資料，維持付款人與分攤成員選擇器可操作。

#### Scenario: 離線時付款人下拉選單可用
- **WHEN** 使用者在離線狀態下開啟新增消費畫面
- **THEN** 付款人選擇器顯示 group_members_cache 中的成員列表（不為空時）

#### Scenario: 離線時分攤成員 Chip 可用
- **WHEN** 使用者在離線狀態下開啟新增消費畫面
- **THEN** 分攤成員區域顯示 group_members_cache 中的成員，可正常勾選

---

## ADDED Requirements

### Requirement: 離線送出後顯示專用 SnackBar
離線狀態下成功儲存消費至 pending queue 後，系統 SHALL 顯示有別於線上成功的 SnackBar 提示。

#### Scenario: 離線儲存成功 SnackBar
- **WHEN** 消費成功存入 pending_expenses（無網路）
- **THEN** 顯示 SnackBar「已離線儲存，稍後將自動同步」，並關閉新增消費畫面
