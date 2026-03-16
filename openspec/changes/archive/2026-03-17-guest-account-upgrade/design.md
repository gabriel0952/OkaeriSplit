## Context

訪客帳號使用 Supabase Auth magic link + 合成 email（`guest-{uuid}@internal.okaerisplit.app`）建立，metadata 帶有 `is_guest: true`。目前訪客沒有主動登出的入口，群組封存時才會被動刪除。

需解決：
1. **退出**：訪客應能主動登出，清除 local session，回到登入畫面。
2. **帳號升級**：訪客可輸入真實 email + 密碼，將臨時帳號轉為永久帳號，保留群組成員身份與歷史紀錄。

---

## Goals / Non-Goals

**Goals:**
- 訪客可在群組頁點擊「退出訪客模式」，完整清除 session 並回到 `/login`
- 訪客可啟動升級流程，輸入 email + 密碼，完成後以正式帳號繼續使用
- 升級後的帳號在群組封存流程中不被誤刪
- 升級後 `isGuest` 旗標消失，解鎖完整 app 功能（Dashboard、Profile 等）

**Non-Goals:**
- v1 不支援以 Google / Apple OAuth 升級（OAuth identity linking 較複雜，排入後續）
- 不支援跨裝置遷移訪客 session（訪客本來就是單裝置設計）
- 升級後不需要 email 驗證（admin 端直接更新，降低流程摩擦）

---

## Decisions

### 1. 退出機制：直接呼叫 signOut + 清 Hive

呼叫既有 `supabase.auth.signOut()`，再清除 Hive 的 `guest_group_id` key。Router 偵測到 session 為 null 會自動導到 `/login`。

不需要新的 Edge Function 或資料庫操作，訪客帳號仍保留在 Supabase（下次仍可用同一組代碼登入，直到群組封存）。

### 2. 帳號升級：Edge Function `upgrade_guest_account`

用 Supabase admin API 直接在 server 端更新 auth user，不走 client-side `updateUser()`（後者需要 email OTP 驗證，流程過長）。

**升級流程：**
```
App → POST /upgrade_guest_account { email, password, display_name }
  ├─ 驗證 email 格式
  ├─ 查 auth.users 確認 email 未被其他帳號占用
  ├─ admin.updateUser(userId, {
  │    email,
  │    password,
  │    email_confirm: true,         // 跳過驗證郵件
  │    user_metadata: { is_guest: false, display_name }
  │  })
  ├─ UPDATE profiles SET is_guest = false, display_name = $display_name
  │    WHERE id = userId
  └─ 回傳 { success: true }
```

**App 端收到成功回應後：**
1. 呼叫 `supabase.auth.refreshSession()` 取得新的 JWT（metadata 已更新）
2. Router 偵測到 `isGuest = false`，解鎖完整導航
3. 導向 `/dashboard` 或繼續停留在當前群組

### 3. archive_group 調整

現有邏輯：封存時刪除群組內所有 `is_guest = true` 的成員帳號。

調整：查詢條件改為同時比對 **profiles.is_guest = true**（帳號已升級的前訪客，profiles 的 is_guest 已改為 false，不受影響）。無需額外判斷。

### 4. UI 進入點

- **退出**：GroupDetailScreen AppBar 的「唯讀」chip 旁新增 icon button（門+箭頭圖示），點擊後跳確認 dialog 再登出。
- **升級**：同一區域或 dialog 底部提供「建立正式帳號」連結，導向 `GuestUpgradeScreen`（新畫面）。

---

## Risks / Trade-offs

- **email 衝突** → Edge Function 先查詢確認，再 update；若已存在回傳 `409 Conflict`，前端提示「此 email 已被使用」
- **升級中途斷線** → admin.updateUser 是原子操作；若 profiles UPDATE 失敗，auth user 已更新但 profiles 仍是舊狀態。Mitigation：profiles UPDATE 失敗時前端提示重試，Edge Function 可用 try/catch 回傳明確錯誤
- **refreshSession 後 isGuest 仍為 true** → Supabase JWT 有快取，若 metadata 未立即反映，Mitigation：升級成功後強制 signOut + signIn with the new credentials（保證拿到新 token）
- **訪客退出後想再進入** → 代碼仍有效（未封存），可在登入頁重新走訪客流程

---

## Migration Plan

1. 部署 `upgrade_guest_account` Edge Function
2. 部署調整後的 `archive_group` Edge Function（排除已升級帳號，已是向後相容）
3. 發布前端版本

無需 DB migration（`profiles.is_guest` 欄位已存在）。

---

## Open Questions

- 升級後是否要寄歡迎 email？（目前設計省略，可後續加 Resend 通知）
- 升級成功後應留在當前群組頁還是跳到 Dashboard？（建議跳 Dashboard，讓用戶感受到「解鎖」）
