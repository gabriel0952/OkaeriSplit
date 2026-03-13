## ADDED Requirements

### Requirement: 封存群組中禁止新增消費
AddExpenseScreen SHALL 偵測群組封存狀態，顯示封存提示並禁用送出按鈕。

#### Scenario: 進入封存群組的新增消費頁
- **WHEN** 使用者導航至已封存群組的 AddExpenseScreen
- **THEN** 頁面頂部顯示「此群組已封存，無法新增或編輯消費」提示，送出按鈕禁用

#### Scenario: RLS 拒絕封存群組的消費寫入
- **WHEN** expenses 表收到封存群組的 INSERT 或 UPDATE
- **THEN** RLS policy 拒絕操作並回傳錯誤
