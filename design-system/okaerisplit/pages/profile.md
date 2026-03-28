# Page Override: Profile Screen（我的）

> 繼承 MASTER.md，以下規則覆蓋或補充。

## 佈局
1. Avatar（96px circle，置中）
2. 個人資訊卡片（名稱 / email / 幣別）
3. 外觀設定卡片（深色模式）
4. 登出 / 刪除帳號按鈕

## Avatar
- 96px 直徑
- 顯示首字或網路圖片
- 未來支援上傳時加相機 icon overlay

## 深色模式切換
- 使用 `SegmentedButton<ThemeMode>`，三個 segment：系統 / 淺色 / 深色
- `VisualDensity.compact`，font size 12sp
- 放在 Card Padding 內的 Row，不用 ListTile trailing

## 危險操作按鈕
- 登出：`OutlinedButton.icon`，`colorScheme.error` 色
- 刪除帳號：同上，加 `side: BorderSide(color: error)`
- 兩個按鈕之間間距 12px

## 刪除帳號 Dialog
- 維持「輸入刪除確認」pattern（高摩擦是設計意圖）
- 確認文字：`此操作無法復原` 用紅色顯示
