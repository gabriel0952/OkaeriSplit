# 專案：OkaeriSplit

## 技術棧
- Flutter 3.x / Dart 3.x
- 狀態管理：Riverpod
- 導航：go_router
- 後端：Supabase / Firebase
- 本地儲存：Hive

## 專案結構
```
lib/
├── core/          # 共用元件、常數、工具
├── features/      # 功能模組 (按 feature 分)
│   └── auth/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── routing/       # 路由設定
└── main.dart
```

## 編碼規範
- Widget 優先使用 const constructor
- 每個 feature 獨立一個資料夾
- 使用 freezed 做 data class
- 錯誤處理使用 Either (fpdart)

## 禁止事項
- ❌ 不要修改 ios/*.pbxproj
- ❌ 不要在 widget 內直接呼叫 API
- ❌ 不要使用 setState（統一用 Riverpod）

## 平台特殊處理
- iOS: 深色模式要支援 Cupertino 風格
- Android: 最低支援 API 24

## 外部文件參考
- 產品需求：docs/PRD.md
- 技術規格：docs/SPEC.md
- UI 設計：[Figma 連結]