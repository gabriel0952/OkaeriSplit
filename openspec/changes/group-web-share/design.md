## Context

OkaeriSplit 目前是純 Flutter app，帳務資訊只能在 app 內查看。
此次新增「分享連結」功能，讓任何人（含未安裝 app 者）都能透過瀏覽器查看群組的消費總覽與帳務狀態。

後端使用 Supabase（PostgreSQL + RLS + RPC）；新增 Next.js 網頁專案部署於 Vercel。
`share_plus` 套件已存在於 `pubspec.yaml`。

## Goals / Non-Goals

**Goals:**
- 允許 app 使用者從 GroupDetailScreen 產生公開分享連結
- 公開網頁（無需登入）呈現群組名稱、成員帳務狀態、消費清單
- 進行中群組：即時查詢 DB；封存群組：同樣即時查詢（資料已不可變，天然快照）
- Token 有效期限（長期，例如 1 年）；過期後連結失效

**Non-Goals:**
- 網頁端互動操作（標記已付款、新增消費等）
- 轉帳資訊顯示（v1 不做）
- BalanceScreen 分享按鈕
- 群組欠款分享 / 請款功能

## Decisions

### 1. Token 策略：share token 而非使用者 auth 連結

**選擇**：在 `share_links` table 儲存隨機 token，URL 形式為 `/s/<token>`。

**理由**：
- 無需訪客登入，降低摩擦
- URL 本身難以猜測（128-bit random），安全性足夠
- 不依賴 Supabase magic link，不受 OTP expiry 限制

**替代方案**：Supabase signed URL — 需要 storage bucket，不適合 DB 資料。

---

### 2. 資料存取：Supabase RLS + anon key

**選擇**：在 RLS policy 中允許 anon 角色，若 `share_links` 存在對應有效 token，則可讀取該群組的 `groups`、`members`、`profiles`、`expenses` 資料。

**理由**：
- Next.js 在 server-side 用 anon key + token 查詢，不需要暴露 service role key
- RLS 確保只有 token 對應的群組資料可被讀取

**替代方案**：Edge Function 作為 proxy — 增加複雜度，且無法享受 Supabase client SDK 的便利。

---

### 3. 建立分享連結：Supabase RPC `create_share_link`

**選擇**：Flutter 呼叫 `create_share_link(p_group_id UUID)` RPC，後端以 `SECURITY DEFINER` 插入 `share_links`，回傳 token。

**理由**：
- 確保 `created_by` 由後端從 `auth.uid()` 取得，不可偽造
- 避免 Flutter 端直接 INSERT（RLS 設定較複雜）

---

### 4. 網頁技術棧：Next.js + MUI，部署 Vercel

**選擇**：`web/` 資料夾放在 monorepo 根目錄，獨立 Next.js 專案。

**理由**：
- MUI 視覺風格接近 Material Design，與 app 一致
- Vercel 免費方案適合此規模
- 與現有 `app/`、`supabase/` 並列管理方便

**路由**：`/s/[token]` — server-side rendering，從 DB 讀取群組資料後渲染。

---

### 5. 資料策略：進行中即時 / 封存即時（天然快照）

**選擇**：兩種群組狀態都直接查詢 DB，不額外做快照。

**理由**：
- 封存群組的消費資料已不可變（封存後不允許新增/修改），直接查詢即為最終狀態
- 避免維護快照同步邏輯

---

### 6. Token 有效期：3 個月

**選擇**：`expires_at = NOW() + INTERVAL '3 months'`，可依需求調整。

**理由**：分享連結通常用於長期分享，過短的有效期影響使用者體驗。

## Risks / Trade-offs

- **連結外洩風險** → Token 為 128-bit random，實際上不可猜測；使用者若不想分享可停止傳播連結（v1 不做撤銷功能）
- **RLS 規則複雜度** → 需要為 `groups`、`expenses`、`members`、`profiles` 分別新增 anon 可讀 policy，需仔細測試避免過寬或過窄
- **Next.js 冷啟動延遲** → Vercel serverless function 首次請求較慢；可考慮 ISR 或 Edge Runtime（v1 先不做）
- **Supabase anon key 暴露** → Next.js 前端 bundle 包含 anon key 是正常設計，RLS 確保資料邊界

## Migration Plan

1. 執行 Supabase migration：建立 `share_links` table、新增 RLS policies、建立 `create_share_link` RPC
2. 部署 Next.js `web/` 至 Vercel，設定環境變數（`NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_ANON_KEY`）
3. 發布新版 Flutter app（含分享按鈕）
4. Rollback：RLS policies 可獨立 DROP；Next.js 可 rollback 部署；Flutter 可 force update

## Open Questions

- Vercel 自訂 domain？→ 部署後決定
