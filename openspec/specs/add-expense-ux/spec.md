# Spec: Add Expense UX

## Requirements

### Requirement: 金額大字 Display 輸入
金額輸入 SHALL 以「大字 Display + 隱藏 TextField」方式呈現。使用者點擊金額區域後彈出系統數字鍵盤。

- Display 字體：fontSize 48，fontWeight 700，letterSpacing -1.0
- 未輸入時顯示灰色 "0" placeholder
- 鍵盤類型：`TextInputType.numberWithOptions(decimal: true)`
- 輸入限制：只接受 `[0-9]` 與一個小數點，小數點後最多 2 位
- 金額區塊固定在頂部，不隨表單捲動

#### Scenario: 點擊金額區彈出鍵盤
- **WHEN** 使用者點擊金額顯示區域
- **THEN** 系統數字鍵盤 SHALL 彈出，使用者可輸入金額

#### Scenario: 輸入非數字字符被阻擋
- **WHEN** 使用者嘗試輸入字母或特殊符號（除小數點外）
- **THEN** 輸入 SHALL 被 `FilteringTextInputFormatter` 攔截，不顯示在 display 上

#### Scenario: 小數點後超過 2 位被限制
- **WHEN** 使用者輸入第 3 位小數
- **THEN** 輸入 SHALL 被忽略，display 維持最多 2 位小數

#### Scenario: 未輸入時顯示 placeholder
- **WHEN** 金額為空或 0
- **THEN** display SHALL 顯示灰色 "0"

---

### Requirement: 幣別 Chip de-emphasize 顯示
幣別 SHALL 以小型 Chip 顯示在金額區左上角，視覺權重低於金額數字。點擊可更換幣別。

#### Scenario: 幣別 Chip 樣式低調
- **WHEN** 幣別為群組預設幣別（如 TWD）
- **THEN** 幣別 Chip SHALL 以小字（fontSize ≤ 13）淺色邊框呈現，不與金額大字競爭視覺焦點

#### Scenario: 點擊幣別可更換
- **WHEN** 使用者點擊幣別 Chip
- **THEN** 應彈出幣別選擇器供切換

---

### Requirement: 橫向可滑動分類 Tile 選擇器
分類選擇 SHALL 使用橫向 `ListView`（不換行），每個分類為圓角正方形 tile。

- Tile 尺寸：寬 60px，高 64px
- Tile 內容：icon 在上，label 在下
- 未選中：淺灰底，深色 icon/text
- 選中：主色填底，白色 icon/text
- 右側固定「+ 自訂」按鈕，不隨 ListView 捲動消失

#### Scenario: 分類橫向滑動
- **WHEN** 分類數量超過螢幕寬度
- **THEN** 使用者 SHALL 可左右滑動瀏覽所有分類

#### Scenario: 選中分類視覺狀態
- **WHEN** 使用者點擊某個分類 tile
- **THEN** 該 tile SHALL 變為主色填底、白色 icon/text；其餘恢復未選中樣式

#### Scenario: 自訂按鈕固定可見
- **WHEN** 分類列表橫向滑動
- **THEN** 「+ 自訂」按鈕 SHALL 始終固定在右側，不被捲動遮擋

---

### Requirement: 付款人頭像 Chip 單選
「誰付的錢」SHALL 以頭像 Chip 列表（Wrap）呈現，每個 Chip 顯示 `CircleAvatar` + 姓名，單選。

- 選中：主色邊框 + ✓ icon
- 未選中：灰色邊框

#### Scenario: 付款人切換
- **WHEN** 使用者點擊另一個成員的頭像 Chip
- **THEN** 之前選中的 Chip 恢復未選中，新點擊的 Chip SHALL 顯示選中樣式

---

### Requirement: 分攤成員頭像 Chip 多選
分攤成員 SHALL 以頭像 Chip 列表（Wrap）呈現，多選，最少選 1 人。

- 選中：主色填底，白字
- 未選中：淺灰底
- 即時摘要文字顯示在 Chips 下方

#### Scenario: 選中成員摘要更新
- **WHEN** 使用者勾選/取消勾選分攤成員
- **THEN** 摘要文字 SHALL 即時更新（如「平均分給 3 人，每人 $400.00」）

#### Scenario: 最少一人限制
- **WHEN** 只剩 1 個成員被選中，使用者嘗試取消勾選
- **THEN** 操作 SHALL 被忽略，至少保留 1 人選中

---

### Requirement: 分帳方式 ExpansionTile 折疊
分帳方式 SHALL 以 `ExpansionTile` 呈現，預設折疊。折疊狀態的 header SHALL 顯示目前模式摘要。

摘要格式：
- 均分 → 「分帳方式：均分」
- 自訂比例 → 「分帳方式：自訂比例 (2:1:1)」
- 指定金額 → 「分帳方式：指定金額」
- 項目拆分 → 「分帳方式：項目拆分 (N 個品項)」

展開後：RadioListTile 四選一；選中非均分後，對應輸入 UI 在 RadioListTile 下方 inline 展開。

#### Scenario: 折疊 header 顯示目前模式
- **WHEN** 分帳方式 ExpansionTile 為折疊狀態
- **THEN** header subtitle SHALL 顯示目前分帳方式的摘要文字

#### Scenario: 切換至自訂比例
- **WHEN** 使用者展開分帳方式並選擇「自訂比例」
- **THEN** 每個選中成員下方 SHALL 出現比例輸入框，即時計算分配金額

#### Scenario: 切換至指定金額
- **WHEN** 使用者選擇「指定金額」
- **THEN** 每個選中成員下方 SHALL 出現金額輸入框，並顯示差額提示（差多少/超出多少）

---

### Requirement: 「更多選項」折疊區含日期/備註/附件
日期、備註、附件 SHALL 收納至「更多選項」`ExpansionTile`，預設折疊。

- 編輯模式且 `note != null || attachmentUrls.isNotEmpty` 時，SHALL 預設展開（`_moreOptionsExpanded` state 控制）
- 日期預設今天，點擊開啟 DatePicker
- 備註為 multi-line TextField（maxLines: 2），選填
- 附件：縮圖 Wrap + 新增按鈕（拍照/相簿）

#### Scenario: 新增模式預設折疊
- **WHEN** 使用者以新增模式開啟畫面
- **THEN** 「更多選項」SHALL 預設折疊

#### Scenario: 編輯模式有備註時自動展開
- **WHEN** 使用者以編輯模式開啟畫面且該消費有備註文字
- **THEN** 「更多選項」SHALL 預設展開，顯示備註內容

#### Scenario: 編輯模式有附件時自動展開
- **WHEN** 使用者以編輯模式開啟畫面且該消費有附件
- **THEN** 「更多選項」SHALL 預設展開，顯示附件縮圖

---

### Requirement: 固定底部送出按鈕
送出按鈕 SHALL 固定在 `SafeArea` 底部，不隨表單捲動；顯示為全寬 `FilledButton`。

- Disabled 條件：金額 ≤ 0 **或** 描述空白
- 送出中：顯示 `CircularProgressIndicator(strokeWidth: 2)` 取代文字
- 文字：新增模式「新增消費」，編輯模式「儲存變更」

#### Scenario: 金額為 0 時按鈕 disabled
- **WHEN** 金額顯示為 0 或空
- **THEN** 送出按鈕 SHALL 為 disabled 狀態（無法點擊）

#### Scenario: 描述空白時按鈕 disabled
- **WHEN** 描述輸入框為空
- **THEN** 送出按鈕 SHALL 為 disabled 狀態

#### Scenario: 送出中顯示 loading
- **WHEN** 使用者點擊送出且正在等待 API 回應
- **THEN** 按鈕 SHALL 顯示 loading spinner，不可再次點擊
