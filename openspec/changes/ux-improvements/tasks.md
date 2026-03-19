## 1. 帳務總覽摘要文字優化

- [x] 1.1 Dashboard 帳務摘要「應收」改為「別人欠你」、「應付」改為「你欠別人」
- [x] 1.2 在摘要數字旁加上輔助說明（小字提示或 tooltip），說明金額的計算來源

## 2. 同名成員識別

- [x] 2.1 建立工具函式 `resolveDisplayName(members, member)`：偵測重複名稱並回傳附 email 前綴的顯示名稱
- [x] 2.2 群組成員列表套用 `resolveDisplayName`
- [x] 2.3 消費列表付款人名稱套用 `resolveDisplayName`
- [x] 2.4 欠款/結算列表成員名稱套用 `resolveDisplayName`
- [x] 2.5 新增消費的付款人選單與分攤成員選項套用 `resolveDisplayName`

## 3. 付款按鈕雙向操作

- [x] 3.1 找出結算列表中限制只有 `fromUser` 才能點擊付款按鈕的條件判斷
- [x] 3.2 移除或調整此限制，改為 `fromUser` 與 `toUser`（即當前登入用戶是其中之一）皆可點擊
- [x] 3.3 確認付款確認 dialog 的說明文字清楚表達「標記 [A] 已付款給 [B]」

## 4. 邀請加入後的操作權限修正

- [x] 4.1 確認前端判斷是否顯示「新增消費」等操作按鈕的條件（是否依賴 `joined_via` 欄位或其他標記）
- [x] 4.2 將判斷條件統一改為「使用者是否存在於 group_members」，移除對加入方式的依賴
- [x] 4.3 測試搜尋邀請加入後，群組內所有操作入口（新增消費、新增結算）皆可使用

## 5. 複製消費功能

- [x] 5.1 消費 item 的操作選單（長按 BottomSheet 或 trailing menu）加入「複製此消費」選項
- [x] 5.2 封存群組中複製選項不顯示
- [x] 5.3 AddExpenseScreen 接收可選的 `templateExpense` 參數（`ExpenseEntity?`），存在時預填所有欄位，id 清空、日期改為今天
- [x] 5.4 路由設定：複製消費以 extra 方式傳遞 `templateExpense`，導航至 AddExpenseScreen
- [x] 5.5 itemized 分帳的複製：預填 items 列表（名稱、金額、分攤成員）
- [x] 5.6 驗證複製送出後為獨立新消費，不影響原始消費
