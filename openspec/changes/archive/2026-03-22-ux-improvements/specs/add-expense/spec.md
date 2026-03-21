## ADDED Requirements

### Requirement: 消費列表提供複製操作入口
每筆消費的操作選單（長按或 trailing 選單）SHALL 包含「複製」選項，觸發複製消費流程。

#### Scenario: 操作選單顯示複製選項
- **WHEN** 使用者長按或點擊消費 item 的操作按鈕
- **THEN** 操作選單 SHALL 包含「複製此消費」選項

#### Scenario: 封存群組中複製選項不可用
- **WHEN** 群組已封存，使用者點擊消費操作選單
- **THEN** 複製選項 SHALL 不顯示或顯示為 disabled（因封存群組禁止新增消費）
