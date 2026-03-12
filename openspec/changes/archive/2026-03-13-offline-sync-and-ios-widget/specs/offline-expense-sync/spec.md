## ADDED Requirements

### Requirement: 離線新增消費存入 pending queue
無網路時，使用者送出新增消費表單，系統 SHALL 將消費資料存入本地 Hive `pending_expenses` box，並回傳成功狀態給 UI。

#### Scenario: 離線送出新增消費
- **WHEN** 使用者在無網路狀態下填妥表單並點擊送出
- **THEN** 系統將消費存入 pending_expenses box，並顯示 SnackBar「已離線儲存，稍後將自動同步」

#### Scenario: 離線消費有唯一本地 ID
- **WHEN** 消費存入 pending_expenses
- **THEN** 每筆 pending 消費有 UUID `localId` 作為本地識別碼，防止重複上傳

---

### Requirement: 網路恢復時自動同步 pending queue
`ConnectivityService` 偵測到連線恢復時，系統 SHALL 自動觸發 `SyncService.flush()` 將所有 pending 消費上傳 Supabase。

#### Scenario: 成功上傳並移除 pending 項目
- **WHEN** 網路恢復且 pending_expenses box 有資料
- **THEN** SyncService 依序上傳每筆，成功後從 box 移除，並 invalidate 相關 Provider

#### Scenario: 上傳失敗時保留 pending 項目
- **WHEN** 某筆 pending 消費上傳失敗（網路中斷或 Supabase 錯誤）
- **THEN** 該筆保留於 pending_expenses box，不移除，等待下次 flush

#### Scenario: App 重新開啟時補充同步
- **WHEN** App 從背景切換回前景
- **THEN** 若 isOnline 為 true，自動觸發一次 SyncService.flush()

---

### Requirement: 消費列表顯示「待同步 N 筆」Badge
當 pending_expenses box 有資料時，消費列表 AppBar SHALL 顯示小 Badge。

#### Scenario: 有 pending 消費時顯示 Badge
- **WHEN** pending_expenses box 有 N 筆資料（N > 0）
- **THEN** 消費列表 AppBar 顯示「待同步 N 筆」Chip（indigo 主色底）

#### Scenario: pending 清空後 Badge 消失
- **WHEN** SyncService.flush() 完成後 pending_expenses box 為空
- **THEN** AppBar Badge 自動消失
