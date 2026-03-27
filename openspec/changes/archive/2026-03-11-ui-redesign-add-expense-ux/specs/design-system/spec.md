## ADDED Requirements

### Requirement: Apple 冷白系色彩系統
App SHALL 使用以下色彩規範，取代 Material 3 預設色彩。

| 用途 | Light | Dark |
|------|-------|------|
| Scaffold 背景 | `#F5F5F7` | `#1C1C1E` |
| 卡片 / 容器 | `#FFFFFF` | `#2C2C2E` |
| 主色 (Primary) | `#4F46E5` | `#4F46E5` |
| 正值語義色 | `#16A34A` | `#22C55E` |
| 負值語義色 | `#DC2626` | `#EF4444` |
| 次要文字 | `#6E6E73` | `#AEAEB2` |
| 分隔線 | `rgba(0,0,0,4%)` | `rgba(255,255,255,8%)` |

#### Scenario: Light 模式底色正確
- **WHEN** App 以 Light 模式啟動
- **THEN** Scaffold 背景色應為 `#F5F5F7`，Card 背景色應為 `#FFFFFF`

#### Scenario: Dark 模式底色正確
- **WHEN** App 以 Dark 模式啟動
- **THEN** Scaffold 背景色應為 `#1C1C1E`，Card 背景色應為 `#2C2C2E`

---

### Requirement: 無陰影卡片設計
Card Widget SHALL 使用 `elevation: 0`，不顯示任何 box-shadow；視覺層次靠背景色差（底色 vs 卡片白色）呈現。

#### Scenario: 卡片無陰影
- **WHEN** 任何 Card widget 渲染
- **THEN** 不應出現陰影，圓角 SHALL 為 16px

---

### Requirement: 精緻字距排版
系統字體 SHALL 套用收緊 letterSpacing，建立清晰的視覺層次。

| 層級 | fontSize | fontWeight | letterSpacing |
|------|----------|------------|---------------|
| 金額大字 | 48 | 700 | -1.0 |
| 大標題 | 34 | 700 | -1.0 |
| 標題 | 22 | 700 | -0.5 |
| Section 標 | 17 | 600 | -0.3 |
| Body | 15 | 400 | -0.1 |
| Caption | 13 | 400 | 0 |

#### Scenario: AppBar 標題字體
- **WHEN** AppBar 顯示標題文字
- **THEN** fontSize SHALL 為 17，fontWeight SHALL 為 600，letterSpacing SHALL 為 -0.3

---

### Requirement: AppBar 透明融合
AppBar SHALL 與 Scaffold 背景融合，`elevation` 和 `scrolledUnderElevation` 均為 0。

#### Scenario: 捲動時 AppBar 不加陰影
- **WHEN** ListView 向下捲動超過 AppBar 高度
- **THEN** AppBar 不應出現任何陰影或底線顏色變化

---

### Requirement: NavigationBar 精緻樣式
底部 NavigationBar SHALL 符合以下規格：
- 背景：白色（Light）/ `#2C2C2E`（Dark）
- 頂部 0.5px 細線分隔，顏色同分隔線規範
- Indicator 色：主色 12% opacity
- Label fontSize：11

#### Scenario: NavigationBar 頂部分隔線
- **WHEN** NavigationBar 渲染
- **THEN** 頂部應有 0.5px 分隔線，不應有陰影

#### Scenario: NavigationBar 選中 Indicator
- **WHEN** 使用者選中某個 Tab
- **THEN** Indicator 顏色 SHALL 為主色加 12% opacity

---

### Requirement: 語義色應用於帳務數字
顯示帳務金額時 SHALL 使用語義色：應收/正值用正值語義色，應付/負值用負值語義色。

#### Scenario: 應收金額顯示綠色
- **WHEN** BalanceSummaryCard 顯示「應收」欄位且金額 > 0
- **THEN** 文字顏色 SHALL 使用正值語義色

#### Scenario: 應付金額顯示紅色
- **WHEN** BalanceSummaryCard 顯示「應付」欄位且金額 > 0
- **THEN** 文字顏色 SHALL 使用負值語義色
