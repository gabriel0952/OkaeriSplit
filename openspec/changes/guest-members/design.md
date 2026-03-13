# Guest Members 設計文件

## 核心概念

虛擬成員（Guest Member）是一個純臨時性的訪客身份：
- 現有用戶可在群組中新增虛擬成員，系統產生對應的訪客代碼
- 訪客輸入群組代碼 + 訪客代碼後，取得該群組的唯讀瀏覽權限
- 群組封存後，訪客帳號從系統中完全刪除，session 自動失效
- 無升級路徑，訪客帳號不會轉為正式帳號

## 已定案決策

| 項目 | 決策 |
|------|------|
| 技術路線 | Route A：假 email + Magic Link Token（Edge Function）|
| 認領步驟 | 兩段驗證：群組代碼（邀請碼）+ 訪客代碼 |
| 多裝置支援 | ❌ 不支援，一個訪客代碼只能在一個裝置認領 |
| 多群組訪客 | ❌ 一個裝置只能認領一個代碼 |
| 升級正式帳號 | ❌ 不支援，訪客帳號為純臨時性 |
| 帳號生命週期 | 群組封存後，訪客 auth user 從系統完全刪除 |
| 代碼長度 | 6 位英數字 |

## 狀態機

```
虛擬成員的生命週期：

  [建立]          [已認領]        [失效]
     │                │              │
     ▼                ▼              ▼
  unclaimed ───────▶ claimed ──────▶ deleted
  （等待對方輸入）  （訪客瀏覽中） （群組封存後，帳號完全刪除）
```

## 使用者流程

### 建立虛擬成員（現有用戶）

```
群組詳情 → 「新增成員」→「新增訪客」
  → 輸入顯示名稱（如「小明」）
  → 系統產生訪客代碼

  ┌────────────────────────────────┐
  │  已新增訪客成員：小明           │
  │                                │
  │  訪客代碼：A3F9K2              │
  │  請小明開啟 APP，               │
  │  依序輸入群組代碼與此訪客代碼    │
  │                                │
  │  [複製代碼]  [分享]            │
  └────────────────────────────────┘
```

### 訪客進入群組

```
開啟 APP
  → 點擊「我是訪客」
  → 輸入群組代碼（6 位邀請碼）→ 驗證群組存在
  → 輸入訪客代碼（6 位）→ Edge Function 驗證兩碼吻合
  → 取得 session，進入群組唯讀瀏覽

  訪客主畫面：
  ┌────────────────────────────────┐
  │  👤 訪客：小明                  │
  │  旅行群組                  唯讀 │
  ├────────────────────────────────┤
  │  你的帳務                       │
  │  你欠 Ray    NT$ 850            │
  │  你欠 小花   NT$ 200            │
  ├────────────────────────────────┤
  │  群組消費明細                    │
  │  • 晚餐  NT$1,200  Ray付  3/10 │
  │  • 計程車 NT$340  小明付  3/10  │
  │  ...                           │
  └────────────────────────────────┘
```

### 群組封存（訪客帳號刪除）

```
Owner 封存群組
  → 系統查詢該群組所有 is_guest = true 的成員
  → 呼叫 supabase.auth.admin.deleteUser() 逐一刪除
  → profiles、group_members 記錄隨 CASCADE 自動清除
  → 訪客裝置上的 session 自動失效（token 對應 user 不存在）
```

## 技術路線：Route A 詳細流程

```
【建立虛擬成員】（Edge Function: create_guest_member，使用 Admin key）

  1. 建立 Supabase auth user
       email: guest-{uuid}@internal.okaerisplit.app
       email_confirm: true（跳過驗證，不寄信）
       無密碼

  2. 建立 profile
       is_guest: true
       claim_code: "A3F9K2"（6 位英數，隨機產生）

  3. 加入 group_members


【訪客認領】（Edge Function: claim_guest_member）

  4. APP 傳入 { group_invite_code, claim_code }

  5. Edge Function 驗證：
       - 用 group_invite_code 找到 group_id
       - 用 claim_code 找到 guest profile
       - 確認該 guest 確實是這個 group 的成員
       - 呼叫 admin.generateLink({ type: 'magiclink', email: guest_email })
       - 回傳 hashed_token

  6. APP 呼叫：
       supabase.auth.verifyOtp({ token_hash, type: 'magiclink' })
       → 取得 session，儲存在裝置本地


【群組封存時清理】（Edge Function 或 RPC: archive_group）

  7. 查詢 group_members WHERE group_id = ? 的所有 is_guest = true 成員
  8. 對每個 guest user 呼叫 admin.deleteUser(user_id)
  9. profiles / group_members 因 CASCADE 自動刪除
```

## DB Schema 變更

```sql
-- profiles 新增欄位
ALTER TABLE profiles
  ADD COLUMN is_guest BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN claim_code TEXT UNIQUE;  -- NULL 表示正式用戶

-- 索引
CREATE INDEX idx_profiles_claim_code ON profiles(claim_code)
  WHERE claim_code IS NOT NULL;
```

## RLS 變更

訪客限制必須在 DB 層強制執行，不能只靠 UI 隱藏按鈕。
所有寫入操作的 RLS 政策需加入 `is_guest` 檢查：

```sql
-- 共用輔助函式
CREATE OR REPLACE FUNCTION is_guest_user()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_guest FROM profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 套用範例（expenses_insert）
CREATE POLICY "expenses_insert" ON expenses
  FOR INSERT TO authenticated
  WITH CHECK (
    is_group_member(group_id)
    AND NOT is_guest_user()
  );
```

需要加入此限制的政策：
- `expenses_insert` / `expenses_update` / `expenses_delete`
- `expense_splits_insert` / `expense_splits_update` / `expense_splits_delete`
- `group_members_insert` / `group_members_delete`
- `settlements_insert`

## Edge Function 清單

| Function | 說明 |
|----------|------|
| `create_guest_member` | 建立虛擬成員（auth user + profile + group_member）|
| `claim_guest_member` | 驗證群組代碼 + 訪客代碼 → 回傳 magic link token |
| `archive_group` | 封存群組，同時刪除所有訪客 auth user |

## 訪客權限邊界

| 操作 | 訪客 | 正式用戶 |
|------|------|----------|
| 查看群組消費列表 | ✅ | ✅ |
| 查看消費詳情 | ✅ | ✅ |
| 查看自己的欠款 | ✅ | ✅ |
| 新增消費 | ❌（RLS 擋）| ✅ |
| 編輯 / 刪除消費 | ❌（RLS 擋）| ✅ |
| 標記已付款 | ❌（RLS 擋）| ✅ |
| 邀請 / 新增成員 | ❌（RLS 擋）| ✅ |
| 建立新群組 | ❌（UI 層）| ✅ |

## Spike 結果（已驗證 ✅）

```
✅ admin.generateLink() 可對同一 user 重複呼叫
   每次產生新 token，可支援訪客重新認領（例如重裝 APP）

✅ verifyOtp({ token_hash }) 純 token 模式可行
   不需要原始 magic link URL，APP 端直接用 hashed_token 登入

✅ admin.deleteUser() 後現有 session 立即失效
   群組封存刪除訪客帳號後，訪客裝置的 session 即時中斷
```

## 代碼安全性

6 位英數字（約 5.6 億組合），需搭配 rate limiting：
- `claim_guest_member` Edge Function：同一 IP 每分鐘最多嘗試 5 次
- 連續失敗 10 次後鎖定該訪客代碼
