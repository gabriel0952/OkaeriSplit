## ADDED Requirements

### Requirement: HomeWidgetService 將群組資料寫入 App Group
Flutter App SHALL 在群組列表更新時，透過 `HomeWidgetService.updateGroups()` 將最多 3 個群組寫入 App Group UserDefaults，並通知 WidgetKit 重新整理。

#### Scenario: 群組列表載入成功後更新 Widget 資料
- **WHEN** groupsProvider 成功取得群組列表
- **THEN** HomeWidgetService.updateGroups() 被呼叫，寫入 JSON payload 至 App Group，並呼叫 HomeWidget.updateWidget()

#### Scenario: App 啟動時初始化 HomeWidgetService
- **WHEN** App 啟動（main.dart）
- **THEN** HomeWidget.setAppGroupId('group.com.raycat.okaerisplit') 被呼叫

---

### Requirement: iOS Widget Extension 顯示群組列表
Widget Extension (SwiftUI) SHALL 從 App Group UserDefaults 讀取群組資料，並以 Medium size Widget 顯示最多 3 個群組的記帳按鈕。

#### Scenario: 有群組資料時正常顯示
- **WHEN** WidgetKit 重新整理且 App Group 有 groups_payload
- **THEN** Widget 顯示最多 3 個群組列（群組名稱 + 幣別 + [+ 記帳] 按鈕）

#### Scenario: 超過 3 個群組時顯示省略
- **WHEN** 群組數量 > 3
- **THEN** Widget 只顯示前 3 個，不顯示其餘

#### Scenario: 無群組資料時顯示提示
- **WHEN** App Group 無 groups_payload 或 groups 陣列為空
- **THEN** Widget 顯示「開啟 App 建立群組」文字

---

### Requirement: 點擊 Widget 按鈕深度連結至新增消費
點擊 Widget 的 [+ 記帳] 按鈕 SHALL 開啟 App 並導航至對應群組的 AddExpenseScreen。

#### Scenario: 點擊記帳按鈕開啟 App
- **WHEN** 使用者點擊 Widget 上某群組的 [+ 記帳] 按鈕
- **THEN** App 收到 URL `com.raycat.okaerisplit://add-expense?groupId=<uuid>` 並導航至 `/groups/<uuid>/add-expense`

#### Scenario: App 未在前景時也能正確導航
- **WHEN** App 在背景或未啟動，使用者點擊 Widget 按鈕
- **THEN** App 啟動後正確解析 deep link 並導航至 AddExpenseScreen
