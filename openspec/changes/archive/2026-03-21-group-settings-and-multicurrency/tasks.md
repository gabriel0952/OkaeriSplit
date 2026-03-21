# Tasks — group-settings-and-multicurrency

## 1. Feature 2 — 移除群組類型 UI（最簡單，先做）
- [ ] 1.1 `create_group_screen.dart`：移除 `_selectedType` 狀態變數與 SegmentedButton，建立時 hardcode `type: 'other'`
- [ ] 1.2 `group_home_screen.dart`：`_buildHeaderContent()` subtitle 從 `${group.type.label} · ${group.currency}` 改為只顯示 `group.currency`

## 2. Feature 1 — 群組名稱編輯

### 2.1 後端 / 資料層
- [ ] 2.1.1 確認 `groups` 表 RLS policy 是否允許 member UPDATE name 欄位；若不允許則新增 policy 至 migration 檔案
- [ ] 2.1.2 `supabase_group_datasource.dart`：新增 `updateGroupName(String groupId, String name)` 方法
- [ ] 2.1.3 `group_repository.dart`（interface）：新增 `Future<Either<Failure, Unit>> updateGroupName(String groupId, String name)`
- [ ] 2.1.4 `group_repository_impl.dart`：實作，呼叫 supabase datasource 並更新 Hive cache
- [ ] 2.1.5 新增 `update_group_name.dart` use case

### 2.2 Provider / UI
- [ ] 2.2.1 `group_provider.dart`：新增 `updateGroupNameUseCaseProvider`
- [ ] 2.2.2 `group_settings_screen.dart`：群組名稱旁加 edit icon；tap 開啟 AlertDialog（TextField + 確認/取消）；成功後 `ref.invalidate(groupDetailProvider)`

## 3. Feature 3 — 多幣別匯率系統

### 3.1 Supabase
- [ ] 3.1.1 新增 migration：建立 `group_exchange_rates` 表與 RLS policies
- [ ] 3.1.2 更新 `get_user_balances` RPC：JOIN `group_exchange_rates`，乘以匯率換算所有金額
- [ ] 3.1.3 更新 `get_overall_balances` RPC（如有需要）

### 3.2 Domain 層
- [ ] 3.2.1 新增 `group_exchange_rate_entity.dart`（groupId, currency, rate, updatedAt）
- [ ] 3.2.2 `group_repository.dart`：新增 `getExchangeRates / setExchangeRate / deleteExchangeRate` 方法
- [ ] 3.2.3 新增 use cases：`get_exchange_rates.dart`、`set_exchange_rate.dart`、`delete_exchange_rate.dart`

### 3.3 Data 層
- [ ] 3.3.1 `supabase_group_datasource.dart`：實作三個匯率 CRUD 方法（SELECT / UPSERT / DELETE）
- [ ] 3.3.2 `group_repository_impl.dart`：實作三個方法

### 3.4 Provider / UI
- [ ] 3.4.1 `group_provider.dart`：新增 `groupExchangeRatesProvider(groupId)` (AsyncNotifierProvider)
- [ ] 3.4.2 `group_settings_screen.dart`：新增「幣別匯率」section
  - 列出已設定匯率（幣別 + 匯率，e.g. 1 USD = 32.5 TWD）
  - 「新增匯率」button → bottom sheet：選外幣 + 輸入 rate
  - Dismissible 滑動刪除
- [ ] 3.4.3 `add_expense_screen.dart`：幣別選擇器改為動態讀取 `groupExchangeRatesProvider`，可選幣別 = 群組幣別 + 已設定匯率的外幣

## 4. 驗證
- [ ] 4.1 建立群組流程無類型選擇
- [ ] 4.2 首頁 header 不出現類型標籤
- [ ] 4.3 群組設定可修改名稱，更新後首頁即時反映
- [ ] 4.4 未設定任何匯率時，記帳只能選群組基礎幣別
- [ ] 4.5 設定 USD 匯率後，記帳可選 USD，帳務總覽金額換算正確
- [ ] 4.6 `flutter analyze` 無新 error
