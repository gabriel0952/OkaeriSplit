## MODIFIED Requirements

### Requirement: 離線時付款人與分攤成員從快取讀取
無網路狀態下進入新增消費畫面，系統 SHALL 從 `group_members_cache` 讀取成員資料，維持付款人與分攤成員選擇器可操作。

#### Scenario: 離線時付款人下拉選單可用
- **WHEN** 使用者在離線狀態下開啟新增消費畫面
- **THEN** 付款人選擇器顯示 group_members_cache 中的成員列表（不為空時）

#### Scenario: 離線時分攤成員 Chip 可用
- **WHEN** 使用者在離線狀態下開啟新增消費畫面
- **THEN** 分攤成員區域顯示 group_members_cache 中的成員，可正常勾選

---

## ADDED Requirements

### Requirement: 離線送出後顯示專用 SnackBar
離線狀態下成功儲存消費至 pending queue 後，系統 SHALL 顯示有別於線上成功的 SnackBar 提示。

#### Scenario: 離線儲存成功 SnackBar
- **WHEN** 消費成功存入 pending_expenses（無網路）
- **THEN** 顯示 SnackBar「已離線儲存，稍後將自動同步」，並關閉新增消費畫面

---

### Requirement: 封存群組中禁止新增消費
AddExpenseScreen SHALL 偵測群組封存狀態，顯示封存提示並禁用送出按鈕。

#### Scenario: 進入封存群組的新增消費頁
- **WHEN** 使用者導航至已封存群組的 AddExpenseScreen
- **THEN** 頁面頂部顯示「此群組已封存，無法新增或編輯消費」提示，送出按鈕禁用

#### Scenario: RLS 拒絕封存群組的消費寫入
- **WHEN** expenses 表收到封存群組的 INSERT 或 UPDATE
- **THEN** RLS policy 拒絕操作並回傳錯誤

---

## ADDED Requirements (receipt-ocr-scanning)

### Requirement: 新增費用頁面提供掃描收據入口
AddExpenseScreen SHALL 保留既有的「掃描收據」按鈕與掃描 bottom sheet，並在既有流程中擴充雙方案掃描能力，而不是新增另一個獨立入口。

#### Scenario: 顯示掃描收據按鈕
- **WHEN** 使用者進入新增費用頁面
- **THEN** 若目前的可用性檢查通過，金額輸入區域旁顯示「掃描收據」按鈕（相機圖示）

#### Scenario: 點擊掃描收據按鈕
- **WHEN** 使用者點擊「掃描收據」按鈕
- **THEN** 系統沿用既有的底部彈出選單，並在原本已有的語言提示與影像來源選擇之外，新增掃描方案選擇（本地 OCR / Gemini）

#### Scenario: 未設定 key 時選擇 Gemini
- **WHEN** 使用者在掃描入口選擇 Gemini，但尚未設定 Gemini API key
- **THEN** 系統不進入掃描結果頁，並引導使用者前往個人設定完成 API key 設定

---

### Requirement: 掃描入口須遵循既有 feature gate
AddExpenseScreen SHALL 以方法級可用性決定掃描入口與選項內容：本地 OCR option 仍受既有可用性檢查控制，Gemini option 則由設定狀態與網路條件控制。

#### Scenario: 本地 OCR 不可用但 Gemini 可使用
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `false`，但使用者已設定 Gemini API key
- **THEN** AddExpenseScreen 仍顯示「掃描收據」入口，且入口中的本地 OCR option 不可選或不顯示，Gemini option 仍可使用

#### Scenario: 本地 OCR 可用但 Gemini 未設定
- **WHEN** `FlutterLocalAi().isAvailable()` 回傳 `true`，且使用者尚未設定 Gemini API key
- **THEN** AddExpenseScreen 顯示「掃描收據」入口，且本地 OCR option 可使用、Gemini option 顯示需先設定 API key

#### Scenario: 沿用既有語言與圖片來源流程
- **WHEN** 使用者在既有掃描 bottom sheet 中選擇任一掃描方案
- **THEN** 系統保留原本已有的 OCR 語言提示與拍照/相簿來源選擇流程，只額外加入掃描方案層

---

### Requirement: 支援從辨識結果自動填入表單
AddExpenseScreen SHALL 接收來自辨識結果頁的資料，自動填入費用表單對應欄位。

#### Scenario: 自動填入金額與說明
- **WHEN** 辨識結果匯入至費用表單
- **THEN** 金額欄位填入辨識的總金額，且僅在說明欄位原本為空時填入「收據掃描」

#### Scenario: 自動切換為項目拆分並填入品項
- **WHEN** 辨識結果包含多個品項且匯入至費用表單
- **THEN** 分攤方式自動切換為「項目拆分」，並以辨識結果覆蓋現有項目列表

#### Scenario: 收據圖片自動加入附件
- **WHEN** 辨識結果匯入至費用表單
- **THEN** 收據原始圖片自動加入附件列表

#### Scenario: 套用結果頁選擇的幣別
- **WHEN** 使用者在掃描結果頁選擇了幣別再匯入
- **THEN** 費用表單應套用該幣別

#### Scenario: 帶回每個品項的成員指派
- **WHEN** 辨識結果中的品項已在結果頁指定分攤成員
- **THEN** 匯入後各 itemized 項目應帶入對應的 `sharedByUserIds`

#### Scenario: 費用表單已有資料時匯入
- **WHEN** 使用者在已填入部分資料的費用表單中執行掃描並匯入
- **THEN** 系統以辨識結果覆蓋金額與品項，但保留使用者既有的付款人與其他未被匯入資料直接覆蓋的表單上下文
