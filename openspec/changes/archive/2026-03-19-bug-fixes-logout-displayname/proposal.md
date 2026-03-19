## Why

登出後重新登入，畫面仍顯示前一個帳號的快取資料，需手動下拉刷新才會更新，對新用戶造成混淆。顯示名稱欄位沒有長度限制，過長名稱會破壞 UI 排版（清單、Avatar、帳務列表）。兩個問題在 beta 測試中被回報，影響基本使用體驗，需優先修復。

## What Changes

- 登出時主動清除所有 Riverpod provider state，確保重新登入後資料從後端重新抓取
- 登出時補清任何殘留的 Hive 快取（除現有 auth box 外補清 groups、expenses、settlements 等）
- 顯示名稱輸入欄位限制最多 20 字元（Profile 編輯、訪客建立、邀請成員）
- 所有顯示名稱的 UI 元件統一加上截斷：超過 20 字元以省略符號呈現

## Capabilities

### New Capabilities

- `display-name-constraints`: 顯示名稱的輸入限制（maxLength）與顯示截斷（overflow ellipsis）規格

### Modified Capabilities

- `hive-cache-layer`: 登出時的快取清除範圍擴展至所有功能快取 box

## Impact

- `app/lib/features/auth/data/repositories/auth_repository_impl.dart` — 登出補清 Riverpod container / invalidate providers
- `app/lib/main.dart` 或 shell — 監聽 auth state 變化，登出時 invalidate 所有相關 providers
- `app/lib/features/profile/` — 顯示名稱編輯欄位加 maxLength
- `app/lib/features/groups/` — 建立訪客、邀請成員等輸入欄位加 maxLength
- 所有顯示 display_name 的 Text widget — 加上 overflow: TextOverflow.ellipsis、maxLines: 1
- `app/lib/features/auth/data/repositories/auth_repository_impl.dart` — 補清 Hive box
