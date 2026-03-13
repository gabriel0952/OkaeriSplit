## Context

目前 `groups` 表沒有生命週期欄位，所有群組永遠處於「可操作」狀態。`GroupEntity` 不帶狀態資訊，`GroupListScreen` 也沒有區段概念。

封存功能需要：
- DB 層面的狀態欄位與寫入保護
- RPC 封裝封存 / 重開邏輯（含 owner 驗證）
- Flutter 端的 UI 適應（列表分區、詳情頁入口、唯讀提示）
- 封存時順帶清理訪客帳號（guest-members 遺留任務）

## Goals / Non-Goals

**Goals:**
- owner 可一鍵封存群組，封存後全員唯讀瀏覽
- 有未結清欠款時警告，但不強制阻擋（owner 決定）
- 封存可撤銷（owner 重新開啟）
- 封存時自動刪除該群組的訪客帳號（is_guest = true）
- 群組列表將封存群組收至「已結束」摺疊區段

**Non-Goals:**
- 多人確認機制（過於複雜，本期不做）
- 封存後自動通知成員（通知系統尚未實作）
- 封存群組的資料匯出功能

## Decisions

**1. 用欄位狀態而非軟刪除**

在 `groups` 表新增 `status TEXT NOT NULL DEFAULT 'active'`，值為 `'active'` 或 `'archived'`。
- 優點：簡單、可撤銷、RLS 可直接用 `status` 篩選
- 替代方案：`archived_at TIMESTAMPTZ`（NULL = active）— 被捨棄，因為多了 nullable 欄位且 RLS 語法較冗長

**2. 封存 / 重開邏輯放在 Supabase RPC（非 Edge Function）**

`archive_group(group_id)` 和 `reopen_group(group_id)` 以 Postgres function 實作，SECURITY DEFINER 確保只有 owner 可呼叫，並在同一 transaction 內完成狀態更新 + 訪客清理（呼叫 Edge Function 或 Postgres 端 delete）。
- 優點：原子性、不需要額外部署 Edge Function
- 訪客清理（deleteUser）需要 admin 權限，Postgres 端無法直接呼叫 Supabase Auth Admin API；因此訪客清理改在 Flutter 端取得訪客 user_id 清單後，呼叫現有的 `supabase.auth.admin.deleteUser` — 但 Flutter client 沒有 admin 權限。**決定：** 改用 Edge Function `archive_group` 統一處理狀態更新與訪客清理。

**3. 訪客清理在 Edge Function 內處理**

`archive_group` Edge Function 執行：
1. 驗證呼叫者為 owner
2. 查詢群組內所有 `is_guest = true` 的成員
3. 逐一呼叫 `admin.deleteUser()`（CASCADE 清理 profiles / group_members）
4. 將 `groups.status` 設為 `'archived'`

**4. RLS 封存寫入保護**

在 expenses、expense_splits、group_members、settlements 的 INSERT/UPDATE/DELETE policy 加入：
```sql
AND (SELECT status FROM groups WHERE id = group_id) = 'active'
```
DB 層做最後防線，Flutter 端 UI 提前阻擋使用者操作。

**5. Flutter 端狀態讀取**

`GroupEntity` 新增 `status` 欄位（`'active'` / `'archived'`），由 `supabase_group_datasource` 的 select 一併回傳。`isArchived` getter 供 UI 判斷。不引入新的 Provider，複用現有 `groupDetailProvider`。

## Risks / Trade-offs

- **訪客清理失敗不回滾**：若 `admin.deleteUser` 部分失敗，群組仍會被封存，但殘留訪客帳號不影響功能（因為 RLS 已限制寫入）。→ 記錄 error log，未來可加補償機制。
- **RLS 效能**：每次寫入都多查一次 `groups.status`。→ `groups(id, status)` 已有 primary key，查詢 O(1)，影響可忽略。
- **重開後訪客帳號不恢復**：封存後訪客帳號已刪除，重開群組後如要再加訪客需重新建立。→ 這是預期行為，符合「重開 = 全新開始」的語意。

## Migration Plan

1. 執行 `supabase/migrations/YYYYMMDD_group_archive.sql`（新增 `status` 欄位、更新 RLS）
2. 部署 `archive_group` Edge Function（`--no-verify-jwt` 不需要，此 function 需驗證 JWT）
3. 部署 Flutter 新版本

Rollback：`ALTER TABLE groups DROP COLUMN status`（RLS policy 同步還原）；Edge Function 刪除即可。

## Open Questions

- 封存群組的邀請碼是否要失效（防止他人用舊邀請碼加入）？目前傾向：封存後 `join_group_by_code` RPC 加 `status = 'active'` 檢查，自然失效。
