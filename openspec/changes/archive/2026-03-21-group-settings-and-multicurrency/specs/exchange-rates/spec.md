# Spec — exchange-rates

## ADDED Requirements

### Requirement: 群組可設定外幣匯率
群組成員可在群組設定中新增、修改、刪除外幣對群組基礎幣別的換算率。

#### Scenario: 查看匯率設定
- **WHEN** 使用者進入群組設定
- **THEN** 顯示「幣別匯率」區塊，列出已設定的外幣與對應匯率（e.g. 1 USD = 32.5 TWD）

#### Scenario: 新增匯率
- **WHEN** 使用者點擊「新增匯率」
- **THEN** 顯示 bottom sheet，可選擇外幣並輸入匯率數值（正數）

#### Scenario: 匯率輸入驗證
- **WHEN** 使用者輸入 0 或負數
- **THEN** 顯示錯誤，不允許儲存

#### Scenario: 修改已有匯率
- **WHEN** 使用者點擊已設定的匯率項目
- **THEN** 開啟編輯介面，允許更新數值

#### Scenario: 刪除匯率
- **WHEN** 使用者滑動刪除某外幣匯率
- **THEN** 該匯率從群組中移除，記帳時該幣別不再可選

### Requirement: 記帳幣別限制
記帳時可選幣別受群組匯率設定限制。

#### Scenario: 無外幣匯率設定
- **WHEN** 群組未設定任何外幣匯率
- **THEN** 記帳幣別選擇器只顯示群組基礎幣別，無法選擇其他幣別

#### Scenario: 有外幣匯率設定
- **WHEN** 群組已設定 USD 匯率
- **THEN** 記帳幣別選擇器顯示群組基礎幣別 + USD（以及其他已設定匯率的幣別）

### Requirement: 分帳計算套用匯率
所有 balance 計算結果以群組基礎幣別表示。

#### Scenario: 混合幣別記帳後查看帳務
- **WHEN** 群組有 TWD 與 USD 兩種幣別的消費（已設定 1 USD = 32.5 TWD）
- **THEN** 帳務總覽顯示的欠款金額均為 TWD，USD 消費已按匯率換算
