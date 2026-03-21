# group-settings-and-multicurrency

## Why

目前群組管理有三個明顯缺口：

1. **群組名稱無法修改**：建立後只能刪除重建，UX 不友善。
2. **群組類型意義不明**：合租 / 旅行 / 活動在產品中無差異行為，僅佔建立流程空間。
3. **多幣別計算錯誤**：記帳時允許選擇任意幣別，但 `get_user_balances` RPC 直接加總不同幣別金額，導致欠款數字混亂；根本原因是系統缺乏幣別換算機制。

## What Changes

### Feature 1 — 群組名稱編輯
- 群組設定頁面新增名稱編輯入口（所有成員可編輯，非 guest）
- 全端新增 updateGroupName 路徑：Supabase → Repository → UseCase → Provider → UI

### Feature 2 — 移除群組類型 UI
- 建立群組流程移除「群組類型」SegmentedButton，type 固定傳 `other`
- 首頁 Header 移除類型標籤，只顯示幣別
- DB 欄位保留，不做 migration

### Feature 3 — 群組匯率系統
- 新增 `group_exchange_rates` 資料表，允許每個群組設定外幣對基礎幣別的換算率
- `get_user_balances` RPC 更新：JOIN 匯率表，所有金額統一換算為群組基礎幣別
- 記帳幣別選擇限制：只有已設定匯率的外幣 + 群組基礎幣別可選
- 群組設定新增「幣別匯率」管理區塊

## Capabilities

### New Capabilities
- `group-name-edit`：群組名稱可由成員即時修改
- `exchange-rates`：群組可設定多組外幣匯率，支援多幣別正確分帳

### Modified Capabilities
- `remove-group-type`：群組類型從建立流程與顯示中移除

## Impact

**新增檔案**
- `supabase/migrations/XXX_group_exchange_rates.sql`
- `app/lib/features/groups/domain/entities/group_exchange_rate_entity.dart`
- `app/lib/features/groups/domain/usecases/update_group_name.dart`
- `app/lib/features/groups/domain/usecases/get_exchange_rates.dart`
- `app/lib/features/groups/domain/usecases/set_exchange_rate.dart`
- `app/lib/features/groups/domain/usecases/delete_exchange_rate.dart`
- `openspec/changes/group-settings-and-multicurrency/specs/*/spec.md`

**修改檔案**
- `app/lib/features/groups/domain/repositories/group_repository.dart`
- `app/lib/features/groups/data/repositories/group_repository_impl.dart`
- `app/lib/features/groups/data/datasources/supabase_group_datasource.dart`
- `app/lib/features/groups/presentation/providers/group_provider.dart`
- `app/lib/features/groups/presentation/screens/group_settings_screen.dart`
- `app/lib/features/groups/presentation/screens/create_group_screen.dart`
- `app/lib/features/groups/presentation/screens/group_home_screen.dart`
- `app/lib/features/expenses/presentation/screens/add_expense_screen.dart`
