## Why

Beta 測試後收到多項 UX 回饋：帳務摘要的「應收/應付/淨額」對新用戶語意不清；同名成員無法在清單中區分；付款確認操作只有欠款方能點擊，收款方也需要此權限；透過搜尋邀請加入的成員仍被要求輸入邀請碼才能操作，造成不必要的重複步驟；消費紀錄缺少複製功能，重複性消費需從頭填寫。這些問題集中影響日常使用流暢度，本次一次修復。

## What Changes

- 帳務總覽摘要改以更直白的文字說明「別人欠你」與「你欠別人」，並加上輔助說明
- 群組成員有同名時，顯示額外識別資訊（email 後綴）以區分
- 結算/欠款列表的「標記付款」按鈕改為雙方（欠款方與收款方）皆可操作
- 透過搜尋邀請加入的成員，加入後自動具備與邀請碼加入相同的編輯權限（移除重複輸入邀請碼的要求）
- 消費列表新增「複製」操作，以現有消費為模板快速建立新消費

## Capabilities

### New Capabilities

- `duplicate-expense`: 從現有消費複製為新消費草稿，開啟新增消費畫面並預填資料

### Modified Capabilities

- `group-members`: 新增同名成員識別顯示規則；修正搜尋邀請加入後即具備完整編輯權限的行為
- `add-expense`: 加入「複製消費」入口（消費列表的操作選單）

## Impact

- `app/lib/features/dashboard/` — 帳務摘要文字調整
- `app/lib/features/settlements/presentation/` — 付款按鈕權限邏輯
- `app/lib/features/groups/` — 成員識別顯示邏輯；邀請加入後權限同步
- `app/lib/features/expenses/presentation/` — 消費列表新增複製選項、新增消費畫面接收預填資料
- `app/lib/routing/` — 複製消費的路由參數傳遞
