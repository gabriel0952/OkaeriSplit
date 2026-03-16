## Why

群組帳務資訊目前只能在 app 內查看，無法分享給沒有安裝 app 的朋友。透過可分享的網頁連結，任何人都能直接在瀏覽器查看群組的消費總覽與帳務狀態，降低分帳資訊傳遞的摩擦。

## What Changes

- **新增 `share_links` 資料表**：儲存分享 token、對應群組、建立者與過期時間
- **新增 Supabase RPC `create_share_link`**：app 端呼叫以建立分享連結，回傳 token
- **新增 GroupDetailScreen 分享入口**：AppBar 加入 share icon，點擊後產生連結並開啟系統分享 sheet
- **新增 Next.js 網頁專案**（`web/` 資料夾）：部署至 Vercel，路由 `/s/[token]` 渲染群組總覽頁面
- **新增 Supabase RLS 規則**：允許持有有效 token 的匿名訪客讀取對應群組資料

## Capabilities

### New Capabilities
- `share-link-creation`: app 端建立分享連結 — 從 GroupDetailScreen 觸發，產生 token 並開啟系統分享 sheet
- `group-share-page`: 網頁群組總覽頁面 — Next.js 渲染，依 token 顯示群組名稱、成員帳務狀態與消費清單

### Modified Capabilities

## Impact

- **新增服務**：`web/`（Next.js + MUI，部署 Vercel）
- **資料庫**：新增 `share_links` table、新增 RLS policies、新增 `create_share_link` RPC
- **Flutter**：`group_detail_screen.dart`（新增分享按鈕）、新增 share use case / repository method
- **依賴**：`share_plus`（Flutter 系統分享）、`@supabase/supabase-js`、`@mui/material`（Next.js 端）
