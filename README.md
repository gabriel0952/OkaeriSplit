# OkaeriSplit（おかえり Split）

OkaeriSplit 是一個以中文使用情境為核心設計的多人分帳 App，目標是讓「記錄消費、拆帳、看誰欠誰、完成結算」這整條流程更直覺、更少步驟。

目前專案已包含 Flutter 主 App、Supabase 後端、以及用於群組分享頁的 Next.js Web。

## 目前功能

- 群組建立、邀請碼加入、搜尋使用者邀請、群組封存
- 訪客成員流程：可先以訪客身分加入，之後再認領或升級帳號
- 消費新增 / 編輯 / 刪除，支援附件與備註
- 多種分帳方式：均分 / 自訂比例 / 指定金額 / 項目拆分
- 項目拆分可持久化保存品項、金額與對應分攤成員，並支援詳情檢視與重新編輯
- 收據掃描流程：拍照或選圖後進行 OCR，整理出可供使用者確認的品項與金額
- 消費搜尋與篩選：關鍵字、分類、付款人、日期區間
- 欠款總覽與最小轉帳建議
- 手動結算與結算紀錄
- Dashboard 與消費統計圖表
- Realtime 同步
- 離線記帳與恢復連線後自動同步
- 群組 Web 分享頁
- iOS Home Widget / 深度連結快速進入群組或記帳
- Light / Dark mode

## 技術棧

| 層級 | 技術 |
| --- | --- |
| App | Flutter 3.x / Dart 3.x |
| 狀態管理 | Riverpod |
| 導航 | go_router |
| 後端 | Supabase（Auth / PostgreSQL / Realtime / Storage） |
| 本地儲存 | Hive |
| 型別模型 | freezed / json_serializable |
| 函式式錯誤處理 | fpdart（Either） |
| OCR | google_mlkit_text_recognition |
| 分享頁 | Next.js |

## 專案結構

```text
OkaeriSplit/
├── app/                    # Flutter 主 App
│   ├── lib/
│   │   ├── core/           # theme、errors、services、共用元件
│   │   ├── features/       # 依功能模組切分
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── expenses/
│   │   │   ├── groups/
│   │   │   ├── profile/
│   │   │   ├── settlements/
│   │   │   └── shell/
│   │   ├── routing/
│   │   └── main.dart
│   └── ios/
├── supabase/
│   ├── functions/          # Edge Functions
│   └── migrations/         # schema / policy / RPC migrations
├── web/                    # 群組分享頁
├── docs/                   # PRD、SPEC、TODO 與其他文件
└── design-system/          # UI 設計資產與規格
```

## 開發環境需求

- Flutter SDK（對應 `app/pubspec.yaml`，目前為 Dart `^3.11.0`）
- Xcode（iOS 開發）
- Android Studio / Android SDK（Android 最低支援 API 24）
- Node.js（Web 分享頁開發）
- Supabase 專案

## App 啟動方式

### 1. 建立 Flutter 環境設定

```bash
cp app/dart_defines.example.json app/dart_defines.json
```

接著在 `app/dart_defines.json` 填入至少以下內容：

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

### 2. 安裝依賴並執行 App

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

### 3. 常用建置指令

```bash
cd app

# iOS
flutter build ios --dart-define-from-file=dart_defines.json

# Android
flutter build apk --dart-define-from-file=dart_defines.json
```

## Web 分享頁啟動方式

```bash
cd web
npm install
npm run dev
```

## Supabase 與手動設定

有些功能仍需在 Supabase / Xcode 端手動設定，程式碼不會自動建立：

- 建立 `receipts` Storage bucket 與對應 RLS policy
- Supabase Redirect URL 加入 `com.raycat.okaerisplit://reset-password`
- 確認 App Group：`group.com.raycat.okaerisplit`

更完整的待辦與手動設定可參考 `docs/TODO.md`。

## 驗證指令

Flutter 端常用驗證：

```bash
cd app
flutter analyze
flutter test test/repository/expense_repository_test.dart test/widget/split_summary_test.dart
```

## 文件

- `docs/PRD.md`：產品需求
- `docs/SPEC.md`：技術規格
- `docs/TODO.md`：手動設定、已知事項與後續規劃
- `CLAUDE.md`：專案開發規範與工作方式

## 版本

目前 App 版本：`1.8.2+15`

## 授權

Private repository. All rights reserved.
