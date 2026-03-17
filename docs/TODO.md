# OkaeriSplit 開發 TODO

> M1–M9 全部完成，以下僅列待處理事項與未來規劃。

---

## 待處理：手動設定

這些項目需要在 Xcode 或 Supabase Console 手動操作，無法由程式碼自動完成：

- [ ] **Supabase Storage**：建立 `receipts` bucket + RLS policy（收據/照片附件功能依賴）
- [ ] **Xcode App Group**：確認 Runner + OkaeriSplitWidget Extension 皆已加入 `group.com.raycat.okaerisplit`
- [ ] **Supabase Redirect URL**：Authentication → URL Configuration → Redirect URLs 加入 `com.raycat.okaerisplit://reset-password`（忘記密碼功能依賴）

---

## 待處理：已知 Bug / 小問題

- [x] 登出時未清除 Hive 本地快取（已修正：auth_repository_impl.dart 登出後清除 4 個 cache box）
- [x] 訪客升級後 `profiles.email` 未更新（已修正：upgrade_guest_account Edge Function；補修 migration：20260317_fix_upgraded_guest_email.sql）
- [x] 刪除帳號因 FK constraint 失敗（已修正：delete_user_account RPC 依序刪除 splits → expenses → settlements → group_members → profiles；migration：20260317_fix_delete_user_account.sql）
- [x] 加入群組邀請碼大小寫不符（已修正：join_group_by_code RPC 改為 LOWER() 比對；join_group_dialog 改為小寫輸入；migration：20260317_fix_join_group_by_code.sql）

---

## 未來規劃（尚未開始）

| 功能 | 說明 | 優先級 |
|------|------|--------|
| 推播通知 | 提醒付款、新增消費通知 | P2 |
| i18n 多語系 | 預留架構，目前僅中文 | P2 |
| 金流串接 | 預留架構，不在近期計畫 | P2 |

---

## PRD 功能覆蓋對照

| PRD 功能 | 優先級 | 狀態 |
|----------|--------|------|
| 帳號註冊/登入（Email + Google + Apple） | P0 | ✅ |
| 建立/加入群組（邀請碼） | P0 | ✅ |
| 新增消費記錄 | P0 | ✅ |
| 消費分類（含自訂分類） | P0 | ✅ |
| 均分分帳 | P0 | ✅ |
| 欠款總覽 | P0 | ✅ |
| 手動標記已付款 | P0 | ✅ |
| 基本 Dashboard | P0 | ✅ |
| 自訂比例 / 指定金額分帳 | P1 | ✅ |
| 多幣別支援 | P1 | ✅ |
| 搜尋用戶邀請 | P1 | ✅ |
| 最簡化轉帳演算法 | P1 | ✅ |
| 群組消費統計 | P1 | ✅ |
| Realtime 即時同步 | P1 | ✅ |
| 深色模式 | P1 | ✅ |
| 刪除群組 | P1 | ✅ |
| 項目拆分分帳 | P2 | ✅ |
| 收據/照片附件 | P2 | ✅（Storage bucket 需手動設定）|
| 訪客成員（新增、認領、升級、退出） | P2 | ✅ |
| 群組封存與重新開啟 | P2 | ✅ |
| 群組網頁分享（無需登入） | P2 | ✅ |
| 忘記密碼 / 重設密碼 | P2 | ✅（Supabase Redirect URL 需手動設定）|
| 離線記帳 & 自動同步 | — | ✅ |
| 消費搜尋 & 篩選 | — | ✅ |
| UX 優化 | — | ✅ |
| UI 視覺翻新（Apple 冷白系） | — | ✅ |
| 新增消費 Progressive Disclosure | — | ✅ |
| Skeleton Loading / Empty States | — | ✅ |
| Offline Banner / Expandable FAB | — | ✅ |
| iOS Home Widget | — | ✅ |
| 推播通知 | P2 | ❌ 未開始 |
| i18n 多語系 | P2 | ❌ 未開始 |
| 金流串接 | P2 | ❌ 未開始 |
