## Why

目前「總覽」頁面顯示跨群組的應收/應付/淨額加總，但多幣別情境下數字毫無意義，且沒有任何可執行的行動，使用者無法從這頁做任何事，只能再進入各群組操作，造成認知負擔與混淆。

## What Changes

- 將底部導航的「總覽」tab 重新定位為「待辦」tab（Label 與 Icon 更新）
- 移除現有的跨群組帳務總覽卡片（應收/應付/淨額）
- 移除各群組帳務列表（已在群組列表頁可見）
- 移除最近消費列表（已在各群組內可見）
- 新增「你需要付款」區塊：顯示跨所有群組中使用者欠款的 SimplifiedDebt 項目
- 新增「別人欠你」區塊：顯示跨所有群組中別人欠使用者的項目
- 每筆項目顯示：對方姓名、所屬群組名、幣別金額
- 點擊項目跳轉至對應群組的結算頁面（`/groups/:groupId/balances`）
- 帳款全清時顯示 empty state

## Capabilities

### New Capabilities

- `cross-group-pending-debts`: 跨群組聚合目前使用者的待辦欠款清單（付款方向 + 收款方向），以 SimplifiedDebt 為基礎，每筆附帶群組資訊

### Modified Capabilities

<!-- 無現有 spec 需要修改 -->

## Impact

- **修改檔案**：`dashboard_screen.dart`、`dashboard_provider.dart`、`main_shell.dart`
- **新增邏輯**：跨群組 provider 聚合 `simplifiedDebtsProvider` 的結果
- **不影響**：群組功能、結算流程、所有其他 providers
- **Guest 使用者**：目前已被 redirect 至 groups tab，不受影響
