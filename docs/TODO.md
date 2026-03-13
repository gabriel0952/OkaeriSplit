# OkaeriSplit 開發 TODO

> M1–M9 全部完成，以下僅列待處理事項與未來規劃。

---

## 待處理：手動設定

這些項目需要在 Xcode 或 Supabase Console 手動操作，無法由程式碼自動完成：

- [ ] **Supabase Storage**：建立 `receipts` bucket + RLS policy（收據/照片附件功能依賴）
- [ ] **Xcode App Group**：確認 Runner + OkaeriSplitWidget Extension 皆已加入 `group.com.raycat.okaerisplit`

---

## 待處理：已知 Bug / 小問題

- [x] 登出時未清除 Hive 本地快取（已修正：auth_repository_impl.dart 登出後清除 4 個 cache box）

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
| 消費搜尋 & 篩選 | — | ✅ |
| UX 優化 | — | ✅ |
| UI 視覺翻新（Apple 冷白系） | — | ✅ |
| 新增消費 Progressive Disclosure | — | ✅ |
| Skeleton Loading / Empty States | — | ✅ |
| Offline Banner / Expandable FAB | — | ✅ |
| iOS Home Widget | — | ✅ |
| 離線記帳 & 自動同步 | — | ✅ |
| 推播通知 | P2 | ❌ 未開始 |
| i18n 多語系 | P2 | ❌ 未開始 |
| 金流串接 | P2 | ❌ 未開始 |
