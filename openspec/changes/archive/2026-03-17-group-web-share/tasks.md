## 1. 資料庫 Migration

- [x] 1.1 建立 `share_links` table（token、group_id、created_by、expires_at、created_at）
- [x] 1.2 建立 Supabase RPC `create_share_link(p_group_id UUID)`（SECURITY DEFINER，驗證成員身份、產生 token、插入 share_links、回傳 token）
- [x] 1.3 新增 RLS policy：允許 anon 角色在有效 token 存在時讀取 `groups` 對應資料
- [x] 1.4 新增 RLS policy：允許 anon 角色在有效 token 存在時讀取 `group_members` 對應資料
- [x] 1.5 新增 RLS policy：允許 anon 角色在有效 token 存在時讀取 `profiles` 對應資料
- [x] 1.6 新增 RLS policy：允許 anon 角色在有效 token 存在時讀取 `expenses` 對應資料

## 2. Flutter — 分享功能

- [x] 2.1 新增 `ShareRepository` / `GroupRepository` method：呼叫 `create_share_link` RPC，回傳 token 字串
- [x] 2.2 新增 `CreateShareLinkUseCase`：接受 groupId，回傳 `Either<Failure, String>`（token）
- [x] 2.3 新增 `createShareLinkUseCaseProvider`
- [x] 2.4 在 `GroupDetailScreen` AppBar 新增分享 icon 按鈕
- [x] 2.5 點擊分享按鈕：呼叫 use case → 組合 URL → 呼叫 `share_plus` 開啟系統分享 sheet
- [x] 2.6 按鈕 loading 狀態處理（呼叫中停用按鈕）及錯誤 snackbar

## 3. Next.js 網頁專案初始化

- [x] 3.1 在 monorepo 根目錄建立 `web/` 資料夾，初始化 Next.js 14+ 專案（App Router）
- [x] 3.2 安裝依賴：`@supabase/supabase-js`、`@mui/material`、`@mui/icons-material`、`@emotion/react`、`@emotion/styled`
- [x] 3.3 設定環境變數：`NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_ANON_KEY`
- [x] 3.4 建立 Supabase client（anon key，server-side 用）

## 4. Next.js 網頁 — 分享頁面實作

- [x] 4.1 建立路由 `app/s/[token]/page.tsx`（Server Component，SSR）
- [x] 4.2 依 token 查詢 `share_links` 驗證有效性（存在且未過期）
- [x] 4.3 查詢群組基本資訊（名稱、狀態）
- [x] 4.4 查詢成員列表及帳務淨值（計算每位成員應收/應付）
- [x] 4.5 查詢消費清單（依日期降序）
- [x] 4.6 實作群組總覽頁面 UI：顯示群組名稱、成員帳務狀態（含已結清標記）
- [x] 4.7 實作消費清單 UI：消費名稱、金額、付款人、日期、分類
- [x] 4.8 實作無效/過期 token 的錯誤頁面
- [x] 4.9 確保 RWD（響應式設計）：手機與桌機均正常顯示

## 5. 部署與驗收

- [x] 5.1 將 `web/` 連結至 Vercel，設定環境變數並部署
- [x] 5.2 更新 Flutter 端的分享 URL domain 為正式 Vercel 網址
- [x] 5.3 端對端測試：Flutter 產生連結 → 瀏覽器開啟 → 正確顯示群組資料
- [x] 5.4 測試無效 token、過期 token、不同群組資料隔離
