## ADDED Requirements

### Requirement: 跨群組待辦欠款聚合
系統 SHALL 在「待辦」頁面聚合目前使用者在所有 **active** 群組中的待辦欠款，不包含已封存（archived）群組。

#### Scenario: 顯示使用者欠別人的款項
- **WHEN** 使用者開啟「待辦」頁面
- **THEN** 「你需要付款」區塊顯示所有 active 群組中使用者為付款方（fromUser）的 SimplifiedDebt 項目

#### Scenario: 顯示別人欠使用者的款項
- **WHEN** 使用者開啟「待辦」頁面
- **THEN** 「別人欠你」區塊顯示所有 active 群組中使用者為收款方（toUser）的 SimplifiedDebt 項目

#### Scenario: 封存群組的欠款不顯示
- **WHEN** 使用者所在的某個群組狀態為 archived
- **THEN** 該群組的欠款不出現在「待辦」頁面任何區塊中

#### Scenario: 排序邏輯
- **WHEN** 同一區塊有多個來自不同群組的欠款項目
- **THEN** 項目 SHALL 依所屬群組建立時間（createdAt）升序排列（較早建立的群組優先）

---

### Requirement: 待辦項目的群組資訊顯示
每筆待辦欠款項目 SHALL 顯示：對方姓名、所屬群組名稱、幣別與金額。

#### Scenario: 項目資訊完整顯示
- **WHEN** 待辦欠款項目渲染
- **THEN** 顯示對方頭像（如有）、對方顯示名稱、群組名稱、以及「{currency} {amount}」格式的金額

#### Scenario: 點擊項目跳轉結算頁
- **WHEN** 使用者點擊任一待辦欠款項目
- **THEN** 導航至該群組的結算頁面（`/groups/:groupId/balances`）

---

### Requirement: 區塊小計顯示
系統 SHALL 在每個區塊 header 顯示小計資訊。

#### Scenario: 單一幣別時顯示金額總計
- **WHEN** 某區塊所有項目的幣別相同
- **THEN** header 顯示「共 {currency} {total}」

#### Scenario: 多幣別時顯示筆數
- **WHEN** 某區塊項目含有兩種以上不同幣別
- **THEN** header 顯示「共 N 筆」

---

### Requirement: 結算後自動刷新
使用者從群組結算頁返回「待辦」頁面時，系統 SHALL 自動刷新欠款資料，不需使用者手動下拉。

#### Scenario: 從結算頁返回後資料更新
- **WHEN** 使用者在群組結算頁完成付款標記後返回「待辦」頁面
- **THEN** 「待辦」頁面的欠款清單自動重新載入，已結算的項目不再顯示

---

### Requirement: Empty State — 無群組
系統 SHALL 在使用者尚未加入任何群組時，顯示引導加入群組的 empty state。

#### Scenario: 無群組時顯示引導訊息
- **WHEN** 使用者的群組列表為空
- **THEN** 顯示「加入或建立一個群組，開始記帳」的 empty state，並提供導航至群組頁面的 CTA

---

### Requirement: Empty State — 帳款全清
系統 SHALL 在使用者有群組但所有欠款皆已結清時，顯示正向回饋的 empty state。

#### Scenario: 有群組但無待辦欠款時
- **WHEN** 使用者有至少一個 active 群組，但「你需要付款」與「別人欠你」兩個區塊均無項目
- **THEN** 顯示「帳款都清楚了」的 empty state，不顯示任何區塊
