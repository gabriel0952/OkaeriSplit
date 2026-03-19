## Context

OkaeriSplit 的帳務總覽、群組成員、結算、消費列表功能已實作完整，但使用者研究指出幾個摩擦點：文字語意、成員識別、操作權限與操作效率。本次優化均為 UI 行為調整或新增輕量功能，無後端 schema 變動。

## Goals / Non-Goals

**Goals:**
- 帳務摘要改善可讀性，讓新用戶一眼理解帳務狀態
- 同名成員在所有列表中可被識別
- 付款標記操作改為雙向可操作
- 搜尋邀請加入即享有完整群組操作權限
- 複製消費提升重複記帳效率

**Non-Goals:**
- 不改動後端 schema 或 RLS（邀請管道不同但現有 group_members 欄位已足夠）
- 不新增 member roles / 權限系統
- 複製消費不支援附件複製（附件需重新上傳）

## Decisions

### 1. 帳務摘要文字

**選擇**：將「應收」改為「別人欠你」、「應付」改為「你欠別人」，並在數字旁加上小型說明 icon 或 tooltip 解釋計算邏輯。

**理由**：直述句比財務術語對一般用戶更直覺。icon/tooltip 讓有疑問的用戶可主動查看說明而不干擾主介面。

### 2. 同名成員識別

**選擇**：當群組內有兩位以上 `display_name` 完全相同的成員時，在名稱後附加 email 前綴（`@` 之前的部分，取前 8 字）以括號顯示：`王小明 (wang123)`。

**理由**：email 前綴對用戶有意義且唯一，比流水號更易辨識。僅在有衝突時顯示，不影響一般情況的 UI 簡潔。

### 3. 付款按鈕雙向操作

**選擇**：移除結算列表中「只有 fromUser 才能點擊付款」的限制，改為 fromUser 與 toUser 皆可點擊標記付款。

**理由**：現實中收款方常代為確認收到款項，限制只有付款方操作反而造成不便。後端 RLS 目前允許群組成員 INSERT settlements，邏輯上不需額外 server-side 驗證。

### 4. 邀請加入後的操作權限

**調查**：透過搜尋邀請加入是由群組 owner 呼叫 RPC `invite_user_to_group`（或類似機制）直接將對方加入 `group_members`；邀請碼加入則是用戶自己呼叫 `join_group_by_code`。兩者都在 `group_members` 有一筆記錄，差異可能在於某個欄位（如 `role` 或 `joined_via`）影響了前端的操作入口顯示。

**選擇**：確認前端判斷操作權限的條件，移除對「加入方式」的判斷，統一以「是否在 group_members」作為唯一依據。

**理由**：加入方式是流程細節，不應影響功能權限。

### 5. 複製消費

**選擇**：在消費列表的每筆 item 長按選單（或 trailing 三點選單）加入「複製」選項，點擊後以現有消費資料（描述、金額、分類、付款人、分攤方式）為預填值開啟 AddExpenseScreen，日期預設今天。

**理由**：複用現有 AddExpenseScreen 的預填邏輯（編輯消費已有此機制），只需傳入 `ExpenseEntity` 作為 template 並清除 `id`，成本低。

## Risks / Trade-offs

- [Risk] 同名識別若 email 前綴也重複（極少見）仍無法區分 → Mitigation: 此情境極少，v1 不處理，日後可加 fallback 顯示 user_id 後 4 碼
- [Risk] 複製消費若原消費有 itemized splits，預填邏輯較複雜 → Mitigation: itemized 模式複製時，items 一併複製；如有問題改為降級為均分
- [Risk] 付款雙向操作若 UI 不夠清楚可能誤操作 → Mitigation: 確認 dialog 說明「標記 [A] 已付款給 [B]」讓雙方理解動作含義
