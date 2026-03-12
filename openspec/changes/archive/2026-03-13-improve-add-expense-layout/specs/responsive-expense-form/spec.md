## ADDED Requirements

### Requirement: 表單 padding 根據螢幕寬度自適應
新增消費表單的整體水平/垂直 padding SHALL 根據螢幕寬度動態調整：寬度 < 360pt 時使用 12px，360–599pt 使用 16px，≥ 600pt 使用 24px。

#### Scenario: 小螢幕 padding
- **WHEN** 裝置螢幕寬度為 320pt（如 iPhone SE）
- **THEN** 表單內容距離左右邊緣各 12px

#### Scenario: 一般螢幕 padding
- **WHEN** 裝置螢幕寬度為 390pt（如 iPhone 14）
- **THEN** 表單內容距離左右邊緣各 16px

---

### Requirement: 金額與幣別欄位不溢出
金額輸入欄 SHALL 使用 `Expanded` 填滿剩餘空間；幣別下拉選單 SHALL 以最小寬度 80pt 顯示，不受內容長度影響而超出行寬。

#### Scenario: 小螢幕金額幣別並排
- **WHEN** 使用者在 320pt 寬螢幕開啟新增消費頁面
- **THEN** 金額欄與幣別選單在同一行顯示，無溢出或截斷

#### Scenario: 幣別選單最小寬度
- **WHEN** 選擇任何幣別（TWD、USD、JPY 等）
- **THEN** 幣別選單寬度不小於 80pt

---

### Requirement: 付款人與日期欄位不溢出
付款人與日期欄位在同一行並排時，SHALL 各占等分空間（flex: 1），且文字過長時以省略號截斷，不破壞行寬。

#### Scenario: 長名稱付款人
- **WHEN** 成員名稱超過欄位寬度
- **THEN** 付款人欄顯示省略號，不影響日期欄位置

#### Scenario: 付款人與日期等寬顯示
- **WHEN** 在任何支援螢幕寬度下開啟頁面
- **THEN** 付款人欄與日期欄各佔行寬約 50%

---

### Requirement: 提交按鈕固定於安全區域底部
提交按鈕 SHALL 固定顯示於頁面底部，並在 SafeArea 內，不被 iOS Home Indicator 或 Android 底部導覽列遮蔽。

#### Scenario: iOS 有 Home Indicator 的裝置
- **WHEN** 在 iPhone X 以後的機型上開啟頁面
- **THEN** 提交按鈕顯示於 Home Indicator 上方，不重疊

#### Scenario: 表單內容可滾動至按鈕上方
- **WHEN** 表單欄位數量超過螢幕高度
- **THEN** 使用者可滾動表單，最後一個欄位不被固定按鈕遮蔽

---

### Requirement: 分帳方式 Wrap 換行間距正常
分帳方式選擇的 `Wrap` 元件 SHALL 設定 `spacing` 與 `runSpacing` 各 8pt，確保小螢幕換行時選項之間有足夠間距。

#### Scenario: 小螢幕分帳方式換行
- **WHEN** 螢幕寬度不足以容納所有分帳選項於一行
- **THEN** 選項換行顯示，垂直間距 8pt，不重疊
