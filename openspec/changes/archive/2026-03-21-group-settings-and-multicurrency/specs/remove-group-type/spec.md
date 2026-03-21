# Spec — remove-group-type

## MODIFIED Requirements

### Requirement: 建立群組流程不再詢問類型
群組類型不再是使用者可選擇的欄位。

#### Scenario: 建立群組
- **WHEN** 使用者進入建立群組頁面
- **THEN** 頁面僅顯示群組名稱與幣別欄位，不出現類型選擇器

#### Scenario: 類型預設值
- **WHEN** 使用者送出建立群組表單
- **THEN** 系統自動帶入 `type = 'other'`，使用者無感知

## REMOVED Requirements

### Requirement: 首頁顯示群組類型
- **原行為**：群組首頁 Header 顯示「{類型} · {幣別}」
- **新行為**：僅顯示幣別，類型標籤移除
