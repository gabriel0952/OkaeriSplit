## 1. 資料庫 Migration

- [x] 1.1 新增 migration 檔案，對 `profiles` 表 `ADD COLUMN payment_info JSONB`

## 2. Domain 層

- [x] 2.1 新增 `PaymentInfoEntity`（bank_name, branch?, account_number, account_holder）
- [x] 2.2 在 `UserEntity` 加入 `paymentInfo` nullable 欄位
- [x] 2.3 在 `ProfileRepository` 介面新增 `getPaymentInfo(userId)` 與 `updatePaymentInfo(userId, PaymentInfoEntity?)` 方法
- [x] 2.4 新增 `GetPaymentInfo` use case
- [x] 2.5 新增 `UpdatePaymentInfo` use case

## 3. Data 層

- [x] 3.1 更新 `SupabaseProfileDataSource`：`getProfile` 映射 `payment_info` 欄位
- [x] 3.2 實作 `getPaymentInfo(userId)`：查詢指定使用者的 `payment_info`
- [x] 3.3 實作 `updatePaymentInfo`：將 `PaymentInfoEntity` 序列化為 JSONB 寫回 `profiles`
- [x] 3.4 更新 `ProfileRepositoryImpl` 實作新增的 repository 方法

## 4. Presentation 層 — Provider

- [x] 4.1 在 `profile_provider.dart` 新增 `getPaymentInfoUseCaseProvider` 與 `updatePaymentInfoUseCaseProvider`

## 5. UI — 我的頁面（編輯）

- [x] 5.1 新增 `EditPaymentInfoSheet` widget（銀行名稱、分行選填、帳號、戶名欄位 + FilledButton 儲存）
- [x] 5.2 在 `profile_screen.dart` 加入「匯款資訊」section（ListTile，訪客隱藏）
- [x] 5.3 點擊 ListTile 開啟 EditPaymentInfoSheet，儲存後重新載入 profileProvider

## 6. UI — 群組設定成員詳情 Sheet

- [x] 6.1 新增 `MemberDetailSheet` widget：顯示頭像、名稱、信箱（含複製）、匯款資訊（若有，含複製帳號）、移除成員按鈕（條件顯示）
- [x] 6.2 `MemberDetailSheet` 初始化時呼叫 `getPaymentInfo(userId)` 取得資料，查詢中顯示 loading，失敗顯示提示文字
- [x] 6.3 更新 `group_settings_screen.dart`：移除成員列表的 Dismissible，改為 ListTile onTap 開啟 MemberDetailSheet，傳入 member、isOwner、canRemove 參數
- [x] 6.4 `MemberDetailSheet` 內的移除成員流程：點擊 → 確認 dialog → 執行移除 → 成功後關閉 Sheet 並 invalidate groupMembersProvider
