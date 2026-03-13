## Why

群組目前只有「存在」一種狀態，沒有生命週期的概念。旅行結束後，群組就這樣永遠掛在列表裡。缺少一個讓群組「正式結束」的流程，會讓長期用戶的群組列表越來越雜亂，也無法讓成員有「帳已結清」的明確感受。

## What Changes

- **群組狀態**：新增 `archived` 狀態（預設為 `active`）
- **封存流程**：群組 owner 可發起封存；封存後群組變為唯讀（可瀏覽但不能新增消費）
- **封存條件**：有未結清欠款時警告，但 owner 可選擇強制封存
- **封存後 UI**：群組列表中封存群組移至「已結束」區段，可展開查看歷史

## Capabilities

### New Capabilities

- `group-archive`: 群組封存流程、封存狀態 UI、已封存群組的歷史瀏覽

### Modified Capabilities

- `group-members`: 封存群組中不能新增成員
- `add-expense`: 封存群組中不能新增消費
- `guest-members`: 群組封存後，認領代碼自動失效

## 未決設計問題

1. **是否需要「所有成員確認」流程？**
   - 簡單版：owner 單方面可封存（操作簡單，但可能有人帳未結清）
   - 完整版：需所有成員確認帳目清零才能封存（更嚴謹，但流程複雜）
   - 目前傾向：加警告但不強制，owner 決定

2. **封存能否撤銷？**
   - 目前傾向：可以（owner 可重新開啟群組）

3. **封存後資料保留多久？**
   - 目前傾向：永久保留，僅限唯讀瀏覽

## Impact

- **DB 變更**：`groups` 表新增 `status TEXT DEFAULT 'active'` 欄位（`active` / `archived`）
- **新 RPC**：`archive_group(group_id)`、`reopen_group(group_id)`
- **修改**：`GroupRepositoryImpl`、`GroupDetailScreen`（封存入口）、`GroupListScreen`（已封存區段）
- **修改**：`AddExpenseScreen`、`group_members` 操作 — 封存群組中顯示唯讀提示並禁用操作
