## ADDED Requirements

### Requirement: 使用者可從消費列表複製一筆消費
消費列表中每筆消費的操作選單 SHALL 提供「複製」選項，點擊後以該消費的資料為預填值開啟新增消費畫面。

#### Scenario: 點擊複製開啟預填新增畫面
- **WHEN** 使用者在消費列表點擊某筆消費的「複製」操作
- **THEN** 系統 SHALL 開啟 AddExpenseScreen，並預填：消費名稱、金額、分類、付款人、分攤方式與成員；日期預設今天

#### Scenario: 複製後為獨立新消費
- **WHEN** 使用者完成預填內容並送出
- **THEN** 系統 SHALL 建立一筆全新的消費記錄，不影響原始消費

#### Scenario: 複製 itemized 消費
- **WHEN** 使用者複製一筆分帳方式為 itemized 的消費
- **THEN** 預填資料 SHALL 包含原本的 items 列表（名稱、金額、分攤成員）

#### Scenario: 複製消費不含附件
- **WHEN** 使用者複製一筆有附件（收據照片）的消費
- **THEN** 預填資料 SHALL 不包含附件，使用者需重新上傳
