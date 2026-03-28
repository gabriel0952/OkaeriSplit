# OkaeriSplit — Design System MASTER

> **使用規則：** 開發任何頁面前，先查 `design-system/okaerisplit/pages/[page-name].md`。
> 若該頁面檔案存在，其規則**覆蓋**此 MASTER。
> 若不存在，完全遵守此 MASTER。

---

**Project:** OkaeriSplit — 分帳 App
**Stack:** Flutter 3.x / Material 3 / Riverpod
**Category:** Personal Finance / FinTech Mobile App
**Target:** iOS & Android，繁體中文用戶為主

---

## 1. 設計理念

**風格定位：** Executive Dashboard × Minimal & Direct

- 數字是主角，裝飾越少越好
- 信任感優先：用藍色系 + 金色 CTA，避免玩具感
- 資訊密度適中：一次只看最重要的一件事
- 深淺模式均需完整支援（iOS Dark Mode Cupertino feel）

---

## 2. Color Tokens

### 2.1 主色系（Flutter `ColorScheme.fromSeed` seed 維持不變）

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `primary` | `#4F46E5` | `#818CF8` | 主要互動元素、選取態 |
| `background` | `#F5F5F7` | `#1C1C1E` | Scaffold 背景 |
| `surface` (card) | `#FFFFFF` | `#2C2C2E` | 卡片背景 |
| `onSurface` | `#1D1D1F` | `#F5F5F7` | 主文字 |
| `onSurfaceVariant` | `#6E6E73` | `#AEAEB2` | 次要文字、標籤 |

### 2.2 語義色彩（Semantic Colors）— 散落在各 widget 的 hardcode 集中至此

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `positive` | `#16A34A` | `#22C55E` | 應收、淨額正值、成功狀態 |
| `negative` | `#DC2626` | `#EF4444` | 應付、淨額負值、欠款 |
| `warning` | `#D97706` | `#F59E0B` | 待同步、警告 |
| `gold` (CTA) | `#CA8A04` | `#FBBF24` | 建議轉帳 CTA、Premium 元素 |

> **實作方式：** 建立 `core/theme/app_colors.dart`，定義 `AppColors` class，
> 提供 `AppColors.positiveOf(context)` 等 convenience method。

### 2.3 禁止使用的顏色

- ❌ 紫色 / 粉紅漸層（AI 感，破壞信任）
- ❌ 高飽和鮮豔色（如 `Colors.red`、`Colors.green` Material 原色）
- ❌ 深色模式下使用淺色模式的 hardcode hex

---

## 3. Typography（Flutter TextTheme）

### 3.1 字體

Flutter mobile 使用系統字體（效能最佳），中文走 SF Pro / Noto Sans CJK 系統內建。
若未來要加自訂英文字體，優先選：**IBM Plex Sans**（金融信任感最強）。

### 3.2 TextTheme 規格

| Style | Size | Weight | Letter Spacing | 用途 |
|-------|------|--------|---------------|------|
| `headlineLarge` | 32sp | w700 | -0.5 | 大標題（空帳頁） |
| `headlineMedium` | 28sp | w600 | -0.3 | 金額突出顯示（淨額） |
| `titleLarge` | 22sp | w600 | -0.3 | 群組名稱、頁面標題 |
| `titleMedium` | 16sp | w600 | -0.2 | 卡片標題、章節標題 |
| `titleSmall` | 14sp | w600 | -0.1 | 次要金額、副標題 |
| `bodyLarge` | 16sp | w400 | -0.1 | 表單主要文字 |
| `bodyMedium` | 14sp | w400 | -0.1 | 一般說明文字 |
| `bodySmall` | 12sp | w400 | 0 | 標籤、時間戳記、次要資訊 |
| `labelSmall` | 11sp | w500 | 0 | Badge、chip 文字 |

### 3.3 金額顯示規則

- 淨額（最重要）→ `headlineMedium` + semantic color + w700
- 應收 / 應付（次要）→ `titleSmall` + semantic color + w600
- 個別帳目金額 → `titleSmall` + w700
- 金額永遠靠右對齊

---

## 4. Spacing System（8px Grid）

所有間距使用 8 的倍數：

| Token | Value | 用途 |
|-------|-------|------|
| `space-xs` | 4px | icon 與文字間距 |
| `space-sm` | 8px | 相鄰元素間距、touch target gap |
| `space-md` | 16px | 標準 padding（卡片內、螢幕邊） |
| `space-lg` | 24px | 章節間距 |
| `space-xl` | 32px | 大區塊間距 |

---

## 5. Component Specs（Flutter 實作）

### 5.1 Card

```dart
// 標準卡片規格
CardThemeData(
  color: lightCard,          // #FFFFFF / #2C2C2E
  elevation: 0,
  shadowColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  margin: EdgeInsets.zero,
)
```

### 5.2 Button

| 類型 | 高度 | Radius | 用途 |
|------|------|--------|------|
| `FilledButton` | 52px | 14px | 主要行動（套用、確認） |
| `FilledButton.tonal` | 34–44px | 12px | 次要行動（付款、篩選） |
| `OutlinedButton` | 52px | 14px | 危險操作（登出、刪除）|
| `TextButton` | auto | - | 取消、次要鏈結 |

- **所有按鈕** elevation = 0
- 非同步操作期間必須 disable button + 顯示 `CircularProgressIndicator`

### 5.3 Input Field

```dart
InputDecorationTheme(
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: primary, width: 2),
  ),
  filled: true,
  fillColor: surface,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
)
```

### 5.4 ListTile

- 高度最小 **56px**（touch target ≥ 44px）
- leading icon/avatar 使用 `outlined` 系列
- trailing 金額靠右，語義色彩
- 使用 `Divider(height: 1, thickness: 0.5)` 分隔，不加額外 padding

### 5.5 Bottom Sheet（篩選、操作選單）

- `isScrollControlled: true, useSafeArea: true`
- 頂部有 drag handle（36×4px, radius 2px）
- 標題列 + 「全部清除」按鈕（有篩選時才顯示）
- 底部固定「套用」按鈕，`FilledButton` 全寬

### 5.6 Skeleton Loading

使用現有 `SkeletonBox`，shimmer 動畫 1500ms cycle：
- Light: base `#E5E5EA`, highlight `#F2F2F7`
- Dark: base `#2C2C2E`, highlight `#3A3A3C`

---

## 6. Navigation

### 6.1 Bottom NavigationBar

- 3 個 tab：總覽 / 群組 / 我的
- `NavigationBar` (Material 3)，白色背景 / 深色用 `#2C2C2E`
- indicator color: primary.withAlpha(0.12)
- label font size: 11sp, w500

### 6.2 AppBar

- 透明背景（同 scaffold）
- `centerTitle: true`
- 標題：17sp, w600, letterSpacing -0.3
- elevation = 0, scrolledUnderElevation = 0

### 6.3 路由（go_router）

- 群組詳情：`/groups/:id`
- 新增帳目：`/groups/:id/add-expense`
- 帳務總覽：`/groups/:id/balance`
- 消費紀錄：`/groups/:id/expenses`

---

## 7. UX 規則（Mobile 優先）

### 7.1 Touch Targets（CRITICAL）

- 最小 touch target：**44×44px**
- 相鄰可點擊元素間距：**≥ 8px**
- FAB 固定右下，bottom padding ≥ 16px

### 7.2 Loading States（HIGH）

- 資料載入 → **Skeleton Screen**（而非空白或 spinner）
- 按鈕操作 → disable + inline `CircularProgressIndicator(strokeWidth: 2)`
- Pull-to-refresh → `RefreshIndicator`

### 7.3 Empty States（MEDIUM）

統一使用 `EmptyStateWidget`：
- icon（64px, opacity 0.45）
- title（`titleMedium`）
- subtitle（`bodyMedium`，可選）
- action button（可選）

### 7.4 Error States

- 網路錯誤 → `AppErrorWidget` + retry button
- 離線 → `OfflineBanner`（頂部，低調灰色，非橘色）
- 表單錯誤 → inline 紅色文字，緊靠問題欄位下方

### 7.5 Offline Banner

- 背景：`colorScheme.surfaceContainerHigh`（非 `Colors.orange`）
- 文字：`onSurface` 色，12sp
- icon：`wifi_off_rounded`，15px

### 7.6 動畫

- Micro-interaction：150–200ms, `easeOut`
- 頁面轉場：200–300ms
- Skeleton shimmer：1500ms, `linear`
- **禁止：** 裝飾性 infinite animation
- 尊重 `MediaQuery.of(context).disableAnimations`

---

## 8. 資料呈現規則（FinTech 特有）

### 8.1 金額顯示

- 貨幣符號放金額**前**，中間空格：`TWD 1,234`
- 小數位：整數顯示用 `.toStringAsFixed(0)`，精確計算保留完整精度
- 正值加 `+` 前綴，負值用顏色區分（不加 `-` 符號在數字前）

### 8.2 結算視角（IMPORTANT）

`SimplifiedDebtRow` 應顯示**主觀視角**：
- 我欠對方 → 紅色文字「你欠 [對方名]」+ 淡紅背景
- 對方欠我 → 綠色文字「[對方名] 欠你」+ 淡綠背景
- 第三方之間 → 中性「A → B」

### 8.3 日期格式

- 今天：`今天`
- 昨天：`昨天`
- 本年度：`MM/dd`
- 跨年：`yyyy/MM/dd`

---

## 9. 深色模式

- 完整支援，不允許「僅部分適配」
- 所有顏色必須從 `Theme.of(context)` 或 `AppColors` 取，禁止 hardcode
- 測試清單：
  - [ ] 所有卡片在深色模式下可見（非透明）
  - [ ] 文字對比度 ≥ 4.5:1
  - [ ] 語義色彩使用深色版本（`#22C55E` / `#EF4444`）

---

## 10. Anti-Patterns ❌

| 禁止 | 原因 |
|------|------|
| `Colors.red` / `Colors.green` 直接用 | 明暗模式不適配 |
| Hardcode hex 在 widget 裡 | 無法統一修改 |
| `setState()` 管理跨元件狀態 | 違反 Riverpod 規範 |
| 裝飾性 infinite animation | 分散注意力、耗電 |
| Emoji 當 icon | 無障礙問題，尺寸不一致 |
| `FittedBox` 壓縮金額字體 | 重要數字不應被縮小 |
| 橘色 Offline Banner | 視覺突兀，低優先資訊不應用高警示色 |
| AI purple/pink gradients | 破壞 FinTech 信任感 |

---

## 11. Pre-Delivery Checklist

每次交付 UI 程式碼前確認：

### 視覺品質
- [ ] 無 emoji 當 icon（使用 Material Icons outlined 系列）
- [ ] 金額有正確語義顏色
- [ ] 深淺模式均測試過

### 互動品質
- [ ] 所有非同步按鈕有 loading state
- [ ] Touch target ≥ 44px
- [ ] 相鄰可點擊元素間距 ≥ 8px

### 資料呈現
- [ ] 空狀態使用 `EmptyStateWidget`
- [ ] 載入狀態使用 Skeleton（非空白）
- [ ] 錯誤狀態有 retry 機制

### 離線支援
- [ ] 離線時功能降級而非崩潰
- [ ] 待同步資料有 badge 提示
