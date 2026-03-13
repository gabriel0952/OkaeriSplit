## Why

OkaeriSplit 目前要求所有群組成員必須擁有帳號才能被加入分帳。這個門檻讓「帶朋友一起用」的場景阻力很高——特別是偶爾出遊、不想另外裝 APP 的朋友。

核心需求是：**讓現有用戶能把沒有帳號的人加入分帳，那些人可以用代碼認領自己的身份並瀏覽帳務，之後再選擇是否升級為正式帳號。**

## What Changes

- **新增虛擬成員（Guest Member）**：現有用戶可在群組中新增一個有名字但沒有帳號的虛擬成員，系統產生對應的訪客代碼
- **兩段驗證進入**：訪客依序輸入群組代碼（邀請碼）與訪客代碼，驗證通過後取得該群組的唯讀瀏覽權限
- **訪客瀏覽模式**：可瀏覽群組所有消費明細及自己的欠款狀態，所有寫入操作皆在 RLS 層封鎖
- **純臨時帳號**：群組封存後，訪客 auth user 從系統完全刪除，session 自動失效，無升級路徑

## Capabilities

### New Capabilities

- `guest-members`: 虛擬成員的建立、管理、代碼產生與分享
- `guest-claim-flow`: 兩段驗證（群組代碼 + 訪客代碼）、以訪客模式瀏覽群組帳務
- `guest-cleanup`: 群組封存時自動刪除訪客帳號

### Modified Capabilities

- `add-expense`: 新增消費時付款人與分攤成員選單需包含虛擬成員
- `group-members`: 成員列表需區分正式成員與虛擬成員，並顯示認領狀態

## Impact

- **DB 變更**：`profiles` 表新增 `is_guest BOOLEAN`、`claim_code TEXT UNIQUE`
- **Supabase Anonymous Auth**：需啟用，用於背景建立虛擬成員帳號
- **新 Edge Function 或 RPC**：`claim_guest_member(claim_code)` — 驗證代碼並回傳對應的匿名 session
- **新套件**：`share_plus`（代碼分享，若尚未安裝）
- **修改**：`GroupRepositoryImpl`、`group_members` 相關 Provider、`AddExpenseScreen` 成員選單
- **RLS**：匿名用戶只能讀取自己所在群組的資料，不能寫入
