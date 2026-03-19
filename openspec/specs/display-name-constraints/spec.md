### Requirement: 顯示名稱輸入限制最多 20 字元
所有輸入顯示名稱的欄位 SHALL 限制最多 20 字元（`maxLength: 20`），防止過長名稱破壞 UI 排版。

#### Scenario: 輸入超過 20 字元
- **WHEN** 使用者在顯示名稱欄位輸入超過 20 字元的文字
- **THEN** 系統 SHALL 截止於第 20 字元，不接受後續輸入

#### Scenario: 貼上超過 20 字元的文字
- **WHEN** 使用者貼上超過 20 字元的文字至顯示名稱欄位
- **THEN** 系統 SHALL 只保留前 20 字元

---

### Requirement: 顯示名稱超過長度時以省略符號呈現
所有顯示 display_name 的 UI 元件 SHALL 設定單行顯示並在超出可用寬度時以省略符號（…）截斷。

#### Scenario: 名稱過長在清單中顯示
- **WHEN** 使用者顯示名稱在群組成員列表、消費列表、欠款清單中超出可用寬度
- **THEN** 名稱 SHALL 以單行加省略符號呈現，不換行、不撐開佈局

#### Scenario: 名稱過長在 Avatar 旁顯示
- **WHEN** 帶有 Avatar 的成員 row（帳務列表、結算畫面）中名稱超出可用寬度
- **THEN** 名稱 SHALL 截斷加省略符號，Avatar 仍完整顯示
