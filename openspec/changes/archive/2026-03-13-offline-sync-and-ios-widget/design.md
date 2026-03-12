## Context

OkaeriSplit 目前為 Remote-first 架構：所有讀寫直接走 Supabase，無本地快取層。Hive 已安裝但尚未使用（DataSource 類別為空殼）。本次變更在現有三層架構（Presentation → Domain → Data）上，於 Data 層加入本地快取策略，並新增原生 iOS Widget Extension。

## Goals / Non-Goals

**Goals:**
- 無網路時可瀏覽上次快取的群組/消費列表
- 無網路時可新增消費（pending queue），網路恢復後自動上傳
- iOS 桌面 Widget 顯示群組列表，支援深度連結快速記帳
- 不破壞現有線上流程

**Non-Goals:**
- Android Widget（本次不實作）
- 多裝置 pending 衝突解決（本次以「後寫覆蓋」為接受策略）
- 離線編輯/刪除已存在的消費
- Push notification（另一個功能）

## Decisions

### 決策 1：Cache-aside 策略（非 Write-through）

**選擇**：讀取時順便寫快取（Supabase 回傳 → 寫 Hive → 回傳 UI），寫入時不同步快取。

**理由**：消費的寫入路徑分線上（直接 Supabase RPC）和離線（pending queue）兩條，Write-through 會讓邏輯複雜。Cache-aside 只在讀取時更新快取，實作最簡單且足夠。

**替代方案**：Write-through（每次成功寫入也更新快取）— 快取更即時，但增加複雜度，目前不必要。

---

### 決策 2：ConnectivityService 全域單例（非每個 Repository 自己判斷）

**選擇**：`ConnectivityService` 作為 Riverpod Provider（`connectivityProvider`），所有 Repository 透過 `ref.watch` 取得目前連線狀態。

**理由**：避免各 Repository 各自監聽 `connectivity_plus`，統一來源減少重複訂閱。

---

### 決策 3：pending_expenses 以 Hive Box 儲存（非 SQLite）

**選擇**：使用 Hive `pending_expenses` box，儲存 JSON string list。

**理由**：Hive 已安裝；pending queue 不需要關聯查詢，key-value 足夠；避免引入 sqflite 增加依賴。

---

### 決策 4：SyncService 在網路恢復時觸發（非定時輪詢）

**選擇**：`ConnectivityService` 偵測到 `isOnline = true` 時觸發 `SyncService.flush()`。

**理由**：即時性好、不耗電。失敗的 pending item 保留原位，下次網路恢復時再試，不需要重試計時器。

---

### 決策 5：iOS Widget 使用 `home_widget` 套件（非純 Swift Method Channel）

**選擇**：`home_widget` 套件封裝 App Group UserDefaults 的讀寫，Flutter 端呼叫 `HomeWidget.saveWidgetData()`。

**理由**：避免手寫 Method Channel；`home_widget` 是此場景的標準解法，維護成本低。

Widget Extension 的 SwiftUI 程式碼仍需手動撰寫（Swift），但資料橋接部分由套件處理。

## Risks / Trade-offs

- **快取過期**：使用者在裝置 A 離線時，裝置 B 有新消費，快取資料會不一致。→ 接受，線上時重新讀取會自動更正，無需版本戳記機制。
- **pending queue 重複上傳**：網路恢復時若 App 在背景被 kill，SyncService 未完成。→ `flush()` 在 App foreground 時也呼叫一次（`AppLifecycleObserver`），確保最終一致。
- **iOS Widget Extension 需手動 Xcode 設定**：App Group Capability 和 Widget Extension Target 無法由 Flutter CLI 自動完成。→ tasks.md 明確列出手動步驟，文件化處理。
- **Hive Box 首次為空**：若使用者從未線上讀取過，離線時快取為空列表。→ UI 顯示「無快取資料，請連線後重試」，不崩潰。

## Migration Plan

1. 新增套件（`connectivity_plus`、`home_widget`）並執行 `flutter pub get`
2. 實作 Hive DataSource（groups_cache、expenses_cache、group_members_cache）
3. 修改 Repository 加入 isOnline 判斷
4. 實作 PendingExpenseRepository + SyncService + ConnectivityService
5. 實作 HomeWidgetService（Flutter 端）
6. 手動 Xcode 設定 App Group + Widget Extension（Swift UI）
7. 修改 AppRouter 加入 deep link 解析
8. UI 層加入 pending badge 和離線 SnackBar

**Rollback**：各層獨立，若 Widget Extension 有問題可移除 Target 而不影響 Flutter 主體。離線功能透過 `isOnline` flag 即可快速 disable。

## Open Questions

- Widget Extension 的 Swift 程式碼樣板是否納入此次任務，還是僅建立 Xcode Target 留給後續？→ 本次一併完成基本 SwiftUI 樣板（顯示群組列表 + URL scheme button）。
