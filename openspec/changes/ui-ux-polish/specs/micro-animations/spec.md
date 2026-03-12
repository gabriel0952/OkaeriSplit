## ADDED Requirements

### Requirement: 新增消費成功動畫
在新增消費（add_expense_screen）成功儲存後，SHALL 顯示短暫的確認視覺回饋，再導回消費列表。視覺回饋為：使用 `ScaleTransition` 讓儲存按鈕短暫縮放至 1.1x 後恢復，或顯示全屏 `SnackBar` 含勾選圖示與「消費已新增」文字。離線時顯示「已排程，將於連線後同步」。

#### Scenario: 線上新增消費成功
- **WHEN** 使用者填寫完成並點擊儲存，且裝置在線
- **THEN** 顯示包含勾選圖示的 SnackBar「消費已新增」，然後 pop 回列表頁

#### Scenario: 離線新增消費成功
- **WHEN** 使用者填寫完成並點擊儲存，且裝置離線
- **THEN** 顯示包含 `cloud_upload_outlined` 圖示的 SnackBar「已排程，連線後自動同步」，然後 pop 回列表頁

---

### Requirement: 刪除消費滑出動畫
在消費列表刪除一筆消費時，SHALL 使用 `AnimatedList` + `SizeTransition` 讓被刪除的項目以高度收縮動畫滑出，動畫時長 300ms。

#### Scenario: 刪除消費
- **WHEN** 使用者在消費詳情頁確認刪除並返回列表
- **THEN** 被刪除的消費卡片以 `SizeTransition` 縮減高度至 0 後消失，其他項目平滑上移
