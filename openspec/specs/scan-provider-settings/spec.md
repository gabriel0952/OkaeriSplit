## Purpose
定義 Gemini 掃描金鑰管理與掃描方案設定的 capability，讓使用者可在個人設定中設定、更新及刪除 Gemini API key，並確保金鑰僅保存於裝置本地安全儲存，且在診斷資料與跨帳號情境中不暴露完整金鑰。

## Requirements

### Requirement: 使用者可管理 Gemini 掃描金鑰
系統 SHALL 在個人設定中提供 Gemini 掃描設定入口，讓使用者可新增、更新、刪除自己的 Gemini API key，並查看目前是否已設定。

#### Scenario: 儲存新的 API key
- **WHEN** 使用者在個人設定頁輸入有效格式的 Gemini API key 並儲存
- **THEN** 系統保存該 key，並將設定頁狀態更新為「已設定」

#### Scenario: 更新既有 API key
- **WHEN** 使用者已設定 Gemini API key，重新輸入新 key 並儲存
- **THEN** 系統以新 key 覆蓋舊 key，並保留「已設定」狀態

#### Scenario: 刪除 API key
- **WHEN** 使用者在設定頁選擇刪除 Gemini API key
- **THEN** 系統移除本機保存的 key，並將設定頁狀態更新為「未設定」

---

### Requirement: Gemini API key 僅保存在裝置本地
系統 SHALL 將 Gemini API key 保存在裝置本地安全儲存，而 SHALL NOT 將該 key 同步到使用者 profile、資料庫或其他跨裝置同步機制。

#### Scenario: 重新安裝或更換裝置
- **WHEN** 使用者在新裝置登入，或原裝置刪除 App 後重新安裝
- **THEN** 系統不自動還原先前的 Gemini API key，並要求使用者重新設定

#### Scenario: 讀取個人資料
- **WHEN** 系統讀取使用者的 profile 或其他雲端設定資料
- **THEN** 回傳資料中不包含 Gemini API key

---

### Requirement: Gemini API key 須以平台安全儲存保護
系統 SHALL 使用作業系統提供的安全儲存機制保存 Gemini API key，而 SHALL NOT 以明文將其寫入 Hive 或其他一般本地偏好儲存。

#### Scenario: 儲存 API key
- **WHEN** 使用者成功儲存 Gemini API key
- **THEN** 系統將 key 寫入平台安全儲存，且不在一般本地設定資料中留下完整 key

#### Scenario: 讀取設定頁狀態
- **WHEN** 使用者重新開啟 Gemini 設定頁
- **THEN** 系統只顯示已設定狀態或遮罩後資訊，而不回顯完整 API key

---

### Requirement: 系統不得在診斷資料中暴露 Gemini API key
系統 SHALL NOT 在 analytics、錯誤紀錄、除錯輸出或其他診斷資料中包含完整 Gemini API key。

#### Scenario: 儲存或更新 key 發生錯誤
- **WHEN** 系統在 Gemini API key 的儲存、讀取或刪除流程中發生錯誤
- **THEN** 對使用者與系統診斷輸出的錯誤資訊都不得包含完整 API key

#### Scenario: 顯示設定摘要
- **WHEN** 系統需要顯示 Gemini 設定的摘要資訊
- **THEN** 摘要內容不得包含完整 API key

---

### Requirement: 系統須在設定與使用前提示第三方掃描風險
系統 SHALL 在 Gemini 掃描設定與使用流程中，提示使用者圖片會傳送至第三方模型服務進行分析。

#### Scenario: 首次查看 Gemini 設定
- **WHEN** 使用者第一次進入 Gemini 掃描設定
- **THEN** 系統顯示 Gemini 會將圖片送往第三方服務處理的說明

#### Scenario: 首次選擇 Gemini 掃描
- **WHEN** 使用者在掃描流程中第一次選擇 Gemini 掃描
- **THEN** 系統在繼續前顯示第三方上傳提示

---

### Requirement: Gemini API key 設定須與登入帳號隔離
系統 SHALL 將 Gemini API key 視為目前登入帳號在本機上的個人設定，不得讓其他帳號看到或沿用前一個帳號的 Gemini key。

#### Scenario: 同裝置切換到另一個帳號
- **WHEN** 使用者在同一台裝置登出 A 帳號並登入 B 帳號
- **THEN** B 帳號不得看到或使用 A 帳號先前設定的 Gemini API key

#### Scenario: 登出後清除活躍參考
- **WHEN** 使用者登出目前帳號
- **THEN** 系統須清除目前 session 中對 Gemini API key 的活躍記憶體參考

---

### Requirement: 系統須揭露 Gemini 使用費用由使用者自備 key 承擔
系統 SHALL 在 Gemini 設定與首次使用流程中，清楚告知 Gemini 掃描會消耗使用者自備 API key 的配額與費用。

#### Scenario: 開啟 Gemini 設定
- **WHEN** 使用者進入 Gemini 掃描設定頁
- **THEN** 系統顯示 Gemini usage 會計入使用者自己 API key 配額或費用的說明

#### Scenario: 首次開始 Gemini 掃描
- **WHEN** 使用者第一次確認使用 Gemini 掃描
- **THEN** 系統在繼續前提示此次掃描將使用使用者自己的 API key 配額
