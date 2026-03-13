## 1. DB Migration

- [ ] 1.1 `groups` 表新增 `status TEXT NOT NULL DEFAULT 'active'` 欄位
- [ ] 1.2 新增 RLS 政策：封存群組禁止寫入（expenses、group_members、settlements）
- [ ] 1.3 執行 migration 至 Supabase

## 2. 封存 / 重開 RPC

- [ ] 2.1 建立 `archive_group(group_id UUID)` RPC（僅 owner 可呼叫）
  - 查詢是否有未結清欄款，若有則回傳警告但仍允許封存
  - 將 `groups.status` 設為 `'archived'`
- [ ] 2.2 建立 `reopen_group(group_id UUID)` RPC（僅 owner 可呼叫）

## 3. 訪客帳號清理（來自 guest-members）

- [ ] 3.1 在封存流程中，查詢該群組所有 `is_guest = true` 的成員
- [ ] 3.2 對每個 guest user 呼叫 `auth.admin.deleteUser()`（profiles / group_members 因 CASCADE 自動刪除）

## 4. Flutter — 群組列表

- [ ] 4.1 `GroupListScreen` 區分 `active` / `archived` 群組，封存群組移至「已結束」摺疊區段
- [ ] 4.2 `GroupEntity` 新增 `status` 欄位

## 5. Flutter — 封存入口

- [ ] 5.1 `GroupDetailScreen` 新增「封存群組」入口（僅 owner 可見）
  - 有未結清欠款時顯示警告 Dialog，owner 可選擇強制封存
- [ ] 5.2 新增「重新開啟群組」入口（封存後 owner 可操作）

## 6. Flutter — 封存後唯讀模式

- [ ] 6.1 `GroupDetailScreen` 封存狀態顯示「已封存」badge，隱藏所有寫入入口
- [ ] 6.2 `AddExpenseScreen` 封存群組進入時顯示提示並禁用送出
- [ ] 6.3 `group_members` 操作（邀請、新增訪客）在封存群組中禁用
