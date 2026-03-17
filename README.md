# OkaeriSplit（おかえり Split）

簡潔直覺的多人分帳 APP，讓記帳分帳像回家一樣輕鬆。

## 產品定位

OkaeriSplit 針對台灣使用者設計，解決多人共同消費後「誰欠誰多少」的痛點。相比 Splitwise，我們追求更清晰的總覽介面、更少步驟的記帳流程，以及一目了然的欠款狀態。

## 適用情境

| 情境 | 範例 |
|------|------|
| 室友合租 | 房租、水電、日用品的長期分攤 |
| 旅行分帳 | 機票、住宿、餐飲、門票 |
| 聚餐活動 | 餐廳、KTV、團購等單次活動 |

## 核心功能

- **群組管理** — 建立群組、邀請碼加入、用戶搜尋邀請、成員管理、群組封存
- **訪客成員** — 無需對方事先註冊即可邀請加入群組；訪客可認領帳號並升級為正式會員
- **快速記帳** — 金額、付款人、分類、備註，Card 分區設計一目了然
- **多種分帳** — 均分 / 自訂比例 / 指定金額 / 項目拆分
- **欠款總覽** — 最簡化轉帳演算法，減少多餘轉帳筆數
- **手動結算** — 標記已付款，記錄結算歷史
- **消費篩選** — 關鍵字搜尋、分類 / 付款人 / 日期範圍篩選
- **收據附件** — 拍照或從相簿選取，附件隨消費記錄保存
- **消費統計** — 分類佔比圓餅圖、月度趨勢折線圖
- **網頁分享** — 產生分享連結，無需安裝 App 即可瀏覽群組消費
- **Realtime 同步** — Supabase Realtime，多人同時記帳即時更新
- **離線記帳** — 無網路時仍可新增消費，網路恢復後自動同步
- **iOS Home Widget** — 桌面 Widget 快速記帳，深度連結直達群組
- **深色模式** — 完整 Light / Dark theme 支援

## 技術棧

| 層級 | 技術 |
|------|------|
| Framework | Flutter 3.41.0 / Dart 3.x |
| 狀態管理 | Riverpod |
| 導航 | go_router |
| 後端 | Supabase (Auth + PostgreSQL + Realtime + Storage) |
| Edge Functions | Deno / TypeScript |
| 本地儲存 | Hive |
| Data Class | freezed |
| 錯誤處理 | fpdart (Either) |
| 網頁分享 | Next.js (web/) |
| CI/CD | Xcode Cloud |

## 專案結構

```
app/lib/
├── core/           # 共用模組（theme、errors、constants、widgets、services）
├── features/       # 功能模組（Clean Architecture）
│   ├── auth/       # 登入 / 註冊（Email + Google + Apple + 訪客）
│   ├── dashboard/  # 個人帳務總覽
│   ├── groups/     # 群組管理（含封存、分享）
│   ├── expenses/   # 消費記錄（含離線）
│   ├── settlements/# 結算
│   ├── profile/    # 個人設定
│   └── shell/      # 底部導航殼
├── routing/        # GoRouter 路由設定
└── main.dart

supabase/
├── functions/      # Edge Functions（Deno）
│   ├── create_guest_member/
│   ├── claim_guest_member/
│   ├── upgrade_guest_account/
│   └── archive_group/
└── migrations/     # PostgreSQL schema + RLS + RPC

web/                # Next.js 網頁分享頁面
```

## 開始開發

### 1. 建立憑證檔

複製範本並填入你的 Supabase 憑證：

```bash
cp app/dart_defines.example.json app/dart_defines.json
# 編輯 dart_defines.json，填入 SUPABASE_URL 和 SUPABASE_ANON_KEY
```

> `dart_defines.json` 已加入 `.gitignore`，不會進入版控。

### 2. 安裝依賴並執行

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

### 3. Build

```bash
# iOS
flutter build ios --dart-define-from-file=dart_defines.json

# Android
flutter build apk --dart-define-from-file=dart_defines.json
```

> 使用 Xcode Archive 包版前，請先執行 `flutter build ios --dart-define-from-file=dart_defines.json` 以生成正確的環境設定。

## Supabase 手動設定

首次部署或功能啟用需在 Supabase Dashboard 手動操作：

| 項目 | 位置 | 說明 |
|------|------|------|
| `receipts` Storage bucket | Storage → New bucket | 收據/照片附件功能 |
| Reset Password Redirect URL | Auth → URL Configuration → Redirect URLs | 加入 `com.raycat.okaerisplit://reset-password` |

## Xcode Cloud CI

CI 透過 `app/ios/ci_scripts/ci_pre_xcodebuild.sh` 執行。
需在 Xcode Cloud 的 Environment Variables 中設定以下 Secret：

| 變數名稱 | 說明 |
|----------|------|
| `SUPABASE_URL` | Supabase 專案 URL |
| `SUPABASE_ANON_KEY` | Supabase Anon Key |

## 文件

- [產品需求 (PRD)](docs/PRD.md)
- [技術規格 (SPEC)](docs/SPEC.md)
- [開發計畫 (TODO)](docs/TODO.md)

## 授權

Private — All rights reserved.
