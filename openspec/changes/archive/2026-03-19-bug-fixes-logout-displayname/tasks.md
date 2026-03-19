## 1. 登出快取清除

- [x] 1.1 在 `auth_repository_impl.dart` signOut 方法中補清 `groups_cache`、`expenses_cache`、`group_members_cache` Hive box
- [x] 1.2 確認現有 signOut 已清除 auth 相關 box（auth_box），若未清除一併補上

## 2. 登出 Riverpod State 重置

- [x] 2.1 新增 `invalidateAllDataProviders(Ref ref)` 工具函式，集中列出所有需 invalidate 的 provider（groups、expenses、settlements、balances 等）
- [x] 2.2 在 `ShellScreen`（或最頂層 consumer widget）加上 `ref.listen(authStateProvider, ...)` 偵測 signedOut 事件
- [x] 2.3 signedOut 時呼叫 `invalidateAllDataProviders`，確保 provider 在下次讀取時重新 fetch

## 3. 顯示名稱輸入限制

- [x] 3.1 Profile 編輯畫面的顯示名稱 TextField 加上 `maxLength: 20`
- [x] 3.2 建立訪客成員輸入欄位加上 `maxLength: 20`
- [x] 3.3 搜尋邀請成員若有顯示名稱輸入欄一併加上 `maxLength: 20`

## 4. 顯示名稱截斷

- [x] 4.1 群組列表成員名稱 Text widget 加上 `maxLines: 1, overflow: TextOverflow.ellipsis`
- [x] 4.2 消費列表付款人名稱加上 ellipsis overflow
- [x] 4.3 欠款清單（settlements）成員名稱加上 ellipsis overflow
- [x] 4.4 帳務總覽 Dashboard 成員名稱加上 ellipsis overflow
- [x] 4.5 新增消費付款人選單、分攤成員選項加上 ellipsis overflow
