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

- **群組管理** — 建立群組、邀請碼加入、成員管理
- **快速記帳** — 金額、付款人、日期、分類，3 步完成
- **多種分帳** — 均分 / 自訂比例 / 指定金額
- **欠款總覽** — 誰欠誰多少，一眼看懂
- **手動結算** — 標記已付款，記錄結算歷史
- **離線可用** — 本地優先寫入，上線後自動同步

## 技術棧

| 層級 | 技術 |
|------|------|
| Framework | Flutter 3.x / Dart 3.x |
| 狀態管理 | Riverpod |
| 導航 | go_router |
| 後端 | Supabase (Auth + PostgreSQL + Realtime) |
| 本地儲存 | Hive |
| Data Class | freezed |
| 錯誤處理 | fpdart (Either) |

## 專案結構

```
app/lib/
├── core/           # 共用模組（theme、errors、constants、widgets）
├── features/       # 功能模組（Clean Architecture）
│   ├── auth/       # 登入 / 註冊
│   ├── dashboard/  # 個人帳務總覽
│   ├── groups/     # 群組管理
│   ├── expenses/   # 消費記錄
│   ├── settlements/# 結算
│   ├── profile/    # 個人設定
│   └── shell/      # 底部導航殼
├── routing/        # GoRouter 路由設定
└── main.dart

supabase/
└── migrations/     # PostgreSQL schema + RLS + RPC
```

## 開始開發

```bash
cd app
flutter pub get
flutter run
```

> 首次執行前，請將 `lib/core/constants/app_constants.dart` 中的 Supabase URL 和 Anon Key 替換為你的專案憑證。

## 文件

- [產品需求 (PRD)](docs/PRD.md)
- [技術規格 (SPEC)](docs/SPEC.md)
- [開發計畫 (TODO)](docs/TODO.md)

## 授權

Private — All rights reserved.
