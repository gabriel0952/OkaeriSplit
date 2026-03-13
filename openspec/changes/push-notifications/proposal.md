## Why

用戶被記了一筆帳、或有人標記已付款，目前完全不會收到任何通知。推播通知是分帳 APP 黏著度的核心機制，也是讓用戶在不主動開 APP 的情況下仍能感知帳務變動的唯一方式。

## What Changes

- **推播通知觸發**：以下事件發生時，相關用戶收到推播
  - 有人在你所在的群組新增了一筆消費（且你被分到帳）
  - 有人標記「已向你付款」
  - 你被邀請加入群組（或被加入虛擬成員）
  - （owner）有新成員加入群組
- **通知設定頁**：用戶可在個人設定中開關各類通知
- **裝置 Token 管理**：APP 啟動時注冊 FCM/APNs token 並存至 Supabase

## Capabilities

### New Capabilities

- `push-notifications`: 通知發送機制（Edge Function）、裝置 token 管理、通知偏好設定

## 技術路線（待決定）

### 選項 A：Supabase Edge Function + FCM/APNs 自建
```
DB 事件（DB Webhook）
  → Supabase Edge Function
  → FCM（Android）/ APNs（iOS）
  → 裝置
```
優點：完全掌控、長期成本低
缺點：需設定 Firebase 專案 + APNs 憑證

### 選項 B：Supabase + OneSignal / Expo Notifications
```
DB 事件 → Webhook → OneSignal → 裝置
```
優點：上手快、有管理 Dashboard
缺點：多一個外部依賴，免費方案有限制

> ⚠️ 技術路線尚未決定，需在設計階段確認。

## Impact

- **新 DB 表**：`device_tokens`（user_id, token, platform, created_at）
- **新 DB 表或欄位**：`notification_preferences`（per user 開關設定）
- **新 Supabase Edge Function**：`send-notification`
- **Flutter 端**：`firebase_messaging` 或對應套件、通知設定 UI
- **iOS**：APNs 憑證設定（需手動）
