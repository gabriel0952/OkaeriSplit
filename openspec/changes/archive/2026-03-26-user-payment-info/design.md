## Context

目前 `profiles` 表已有 id、display_name、email、default_currency、is_guest 等欄位，且 RLS 允許所有已登入使用者 SELECT 任何人的 profile（既有設計，用於群組成員查詢）。App 遵循 Clean Architecture：domain entity → repository interface → data source → use case → Riverpod provider → presentation。

帳務結算的入口在 `balance_screen.dart` 的 `SimplifiedDebtRow`，已顯示「誰要付給誰」，是插入匯款資訊查看的最自然位置。

## Goals / Non-Goals

**Goals:**
- 使用者可設定/編輯個人匯款資訊（銀行名稱、分行、帳號、戶名）
- 付款方在帳務結算頁可查看收款方匯款資訊並複製帳號
- 匯款資訊選填，未設定時不顯示任何入口

**Non-Goals:**
- 不串接任何真實轉帳或支付 API
- 不支援多組匯款資訊（一人一組即可）
- 不支援 LINE Pay / 街口等行動支付識別碼（留待未來擴充）
- 訪客帳號不可設定（唯讀，is_guest = true）

## Decisions

### D1：用 JSONB 欄位儲存，而非獨立資料表

在 `profiles` 新增 `payment_info JSONB` nullable 欄位。

**為何不開新表：** 匯款資訊與使用者 1:1 對應，沒有多筆、無需 JOIN，且現有 RLS 政策（所有人可 SELECT profiles）直接適用，省去為新表另建 policy。

**JSONB schema：**
```json
{
  "bank_name": "台灣銀行",
  "branch": "信義分行",       // 選填
  "account_number": "0123456789012",
  "account_holder": "陳小明"
}
```

### D2：Flutter 端以值物件封裝，不用 Map

在 domain 層新增 `PaymentInfoEntity`（immutable），包含四個欄位（branch 為 nullable），確保型別安全，避免散落的 `map['bank_name']` 存取。

### D3：PaymentInfo 查看入口整合進群組設定成員列表

群組設定（`group_settings_screen.dart`）的成員列表改為可點擊，點擊開啟 `MemberDetailSheet`，Sheet 內顯示：
- 成員頭像 + 名稱（header）
- 信箱（可複製）
- 匯款資訊（若有，含複製帳號按鈕）
- 刪除成員按鈕（僅 owner 且非自己可見，取代現有 Dismissible）

現有的 Dismissible swipe-to-dismiss 移除，刪除操作統一由 Sheet 內觸發，確保介面簡潔且刪除前有明確確認流程。

Profile 頁的編輯入口：在「一般設定」card 下方新增「匯款資訊」section（ListTile → 開啟 EditPaymentInfoSheet）。

### D4：MemberDetailSheet 開啟時才查詢 payment_info

`group_settings_screen.dart` 不預先 watch 所有成員的 payment_info。使用者點擊成員後，`MemberDetailSheet` 內部以 `FutureBuilder` 或初始化時 call `getPaymentInfo(userId)` 取得資料並顯示，查詢失敗顯示錯誤文字（不關閉 Sheet）。成員信箱直接由 `GroupMemberEntity` 提供，無需額外查詢。

## Risks / Trade-offs

- **帳號明碼儲存**：payment_info 存在 Supabase，任何群組成員可讀取。這符合使用情境（本就是要給群組成員看的），但需在 UI 說明資料可見範圍 → 在編輯頁加一行提示文字。
- **JSONB 欄位無 schema 驗證**：App 端負責輸入驗證，Supabase 不加 CHECK constraint（為了未來擴充彈性）→ 可接受。
- **SimplifiedDebtRow 查詢 profile 需要 userId**：目前 `SimplifiedDebtEntity` 已有 `toUserId`，可直接用。

## Migration Plan

1. 新增 Supabase migration：`ALTER TABLE profiles ADD COLUMN payment_info JSONB`
2. 更新 Flutter：domain entity → data source → use case → provider → UI
3. 上線後舊資料 `payment_info = null`，UI 正確處理 nullable（不顯示入口）即可回溯相容
