# Page Override: Balance Screen（帳務總覽 / 結算）

> 繼承 MASTER.md，以下規則覆蓋或補充。

## 用途
讓成員一眼看出：我欠誰、誰欠我、需要怎麼轉帳。

## SimplifiedDebtRow（建議轉帳）— 最重要的元件

### 視角標示（REQUIRED）
根據 currentUserId 顯示主觀視角：

| 情況 | 顯示文字 | 文字顏色 | 背景色 |
|------|---------|---------|--------|
| 我欠對方 | `你欠 [對方名]` | `negative` | `negative.withAlpha(0.06)` |
| 對方欠我 | `[對方名] 欠你` | `positive` | `positive.withAlpha(0.06)` |
| 第三方之間 | `A → B` | `onSurface` | 透明 |

### 金額顯示
- 金額：`bodySmall`, `onSurfaceVariant`（輔助資訊，視角標示才是主角）
- 付款按鈕：`FilledButton.tonal`, 64×34px

## DebtRow（成員明細）
- 正值（應收）→ `colorScheme.primary`
- 負值（應付）→ `colorScheme.error`
- 當前用戶的 row 可加淡色背景 highlight

## Empty States
- 無欠款：icon `check_circle_outline`, title `帳目已清空`
- 已結清：`已全部結清！` 置中文字, `onSurfaceVariant` 色
