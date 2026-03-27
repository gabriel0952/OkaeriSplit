## ADDED Requirements

### Requirement: 篩選區塊採 Card 分組佈局
`_FilterSection` SHALL 將各篩選控制項分組為獨立 Card：關鍵字搜尋 Card、分類篩選 Card（僅在有分類時顯示）、付款人與日期範圍合併 Card。Card 之間 SHALL 有 8px 間距。

#### Scenario: 篩選區塊展開時各 Card 可見
- **WHEN** 使用者點擊篩選按鈕展開篩選區
- **THEN** SHALL 依序顯示：搜尋 Card、分類 Card（若有分類）、付款人+日期範圍 Card

#### Scenario: 無分類資料時不顯示分類 Card
- **WHEN** 群組沒有任何消費分類資料
- **THEN** 分類篩選 Card SHALL 不顯示

### Requirement: 篩選區塊外層保留背景底色容器
`_FilterSection` 外層 SHALL 保留 `surfaceContainerLow` 背景色的 `Container`，各 Card 浮在其上形成層次感。

#### Scenario: 篩選區塊背景色
- **WHEN** 篩選區塊展開
- **THEN** 整個篩選區塊背景 SHALL 為 `colorScheme.surfaceContainerLow`，Card 為白色（light）或 `darkCard`（dark）
