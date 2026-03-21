## 1. 路由結構調整

- [x] 1.1 在 `app_router.dart` 將 `/groups/:groupId` 路由從 `GroupDetailScreen` 改為新的 `GroupHomeScreen`（或調整後的 `ExpenseListScreen`）
- [x] 1.2 在 `app_router.dart` 新增 `/groups/:groupId/settings` 路由，對應 `GroupSettingsScreen`

## 2. 建立 GroupHomeScreen（群組主頁）

- [x] 2.1 建立 `app/lib/features/groups/presentation/screens/group_home_screen.dart`，整合 `ExpenseListScreen` 的完整邏輯（消費清單、搜尋、篩選、FAB、offline sync）
- [x] 2.2 實作頂部固定摘要 Header：顯示群組名稱，從 `groupDetailProvider` 讀取
- [x] 2.3 實作結算摘要顯示：從 `balancesProvider` 讀取，顯示至多 2 筆最重要的未結算資訊；全部結算時顯示「已結清」
- [x] 2.4 在 AppBar 右側新增設定圖示（`Icons.settings_outlined`），點擊後 `context.push('/groups/$groupId/settings')`
- [x] 2.5 保留 `PopScope(canPop: !isGuest)` Guest 模式返回限制
- [x] 2.6 保留 `realtimeExpensesProvider` 的 realtime 訂閱（`ref.listen`）

## 3. 建立 GroupSettingsScreen（群組設定頁）

- [x] 3.1 建立 `app/lib/features/groups/presentation/screens/group_settings_screen.dart`
- [x] 3.2 實作群組基本資訊區塊：顯示群組名稱、描述、貨幣，提供編輯功能
- [x] 3.3 實作成員列表區塊：從 `groupMembersProvider` 讀取，顯示成員頭像與名稱
- [x] 3.4 實作成員邀請功能：邀請按鈕開啟 `InviteMemberDialog`；新增訪客按鈕開啟 `AddGuestMemberDialog`；封存群組時隱藏
- [x] 3.5 實作成員移除功能：左滑手勢觸發確認對話框，確認後執行移除（沿用原 `GroupDetailScreen` 的移除邏輯）
- [x] 3.6 實作分享群組連結功能（沿用原 `GroupDetailScreen` 的 `_handleShareLink` 邏輯）
- [x] 3.7 實作「結算」入口：點擊後 `context.push('/groups/$groupId/balances')`
- [x] 3.8 實作「統計」入口：點擊後 `context.push('/groups/$groupId/stats')`
- [x] 3.9 實作「離開群組」選項（非擁有者可見）：確認對話框後執行 `leaveGroupUseCase` 並導回群組列表
- [x] 3.10 實作「刪除群組」選項（僅擁有者可見）：確認對話框後執行 `deleteGroupUseCase` 並導回群組列表
- [x] 3.11 Guest 模式：隱藏邀請、移除、刪除群組等管理操作
- [x] 3.12 初始化 `realtimeGroupMembersProvider` 的 realtime 訂閱（`ref.listen`，僅在 online 時）

## 4. 清理原 GroupDetailScreen

- [x] 4.1 確認 `GroupDetailScreen` 的所有功能已完整移至 `GroupHomeScreen` 或 `GroupSettingsScreen`
- [x] 4.2 移除 `GroupDetailScreen` 或將其標記為廢棄（依實際是否仍被引用決定）
- [x] 4.3 確認原本從 `GroupDetailScreen` 導航至消費清單的路徑（`/groups/:groupId/expenses`）是否仍需保留或可廢除

## 5. 驗證與測試

- [ ] 5.1 手動測試：從群組列表進入群組，確認直接顯示消費清單
- [ ] 5.2 手動測試：結算摘要 Header 正確顯示（有未結算 / 已結清兩種狀態）
- [ ] 5.3 手動測試：設定頁所有功能正常（成員管理、分享、刪除/離開群組）
- [ ] 5.4 手動測試：封存群組在設定頁中隱藏邀請入口
- [ ] 5.5 手動測試：Guest 模式下主頁無法返回、設定頁隱藏管理操作
- [ ] 5.6 手動測試：離線模式下主頁消費清單正常顯示（Hive 快取）
- [ ] 5.7 手動測試：iOS deep link（`com.raycat.okaerisplit://groups/:groupId`）仍正常導航
