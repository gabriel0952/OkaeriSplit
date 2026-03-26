## Why

結算時，使用者需要知道「要付給誰、怎麼付」，但目前 App 沒有儲存任何匯款資訊，只能靠口頭詢問。加入匯款資訊欄位，讓收款方預先填好帳號，付款方在帳務總覽直接查看並複製，無需離開 App。

## What Changes

- 使用者可在「我的」頁面填寫個人匯款資訊（銀行名稱、帳號、戶名）
- 匯款資訊為選填，未填時不對外顯示
- 群組設定的成員列表改為可點擊，點擊開啟成員詳情 Sheet，顯示信箱、匯款資訊，並整合刪除成員操作
- 訪客帳號不支援設定匯款資訊（唯讀限制）

## Capabilities

### New Capabilities

- `user-payment-info`: 使用者個人匯款資訊的儲存、編輯與查看（含複製功能）

### Modified Capabilities

- `group-members`: 群組設定成員列表改為可點擊，整合成員詳情（信箱、匯款資訊）與刪除操作

## Impact

- **資料庫**：`profiles` 表新增 `payment_info` JSONB 欄位（nullable）
- **新增 migration**：`supabase/migrations/` 新增一個 ALTER TABLE migration
- **UserEntity**：新增 `paymentInfo` 欄位（nullable 值物件）
- **ProfileRepository / DataSource**：`updateProfile` 擴充 `paymentInfo` 參數
- **UpdateProfile UseCase**：新增 `paymentInfo` 選填參數
- **profile_screen.dart**：新增「匯款資訊」section，可編輯（FilledButton 開啟 Sheet）
- **group_settings_screen.dart**：成員列表移除 Dismissible，改為 ListTile onTap 開啟 Sheet
- **新增 Widget**：`MemberDetailSheet`（信箱、匯款資訊查看 + 複製、刪除成員）、`EditPaymentInfoSheet`（編輯匯款資訊）
