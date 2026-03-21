# Design — group-settings-and-multicurrency

## Context

OkaeriSplit 目前群組設定為唯讀，建立後不可修改；群組類型欄位在 UI 中無差異行為；多幣別記帳因缺乏換算機制導致分帳計算混亂。本提案同步解決三個問題。

---

## Feature 1 — 群組名稱編輯

### Goals
- 所有成員（非 guest）均可修改群組名稱
- 修改即時同步至所有成員

### Non-Goals
- 不支援修改群組幣別（後續版本）
- 不支援修改 invite code

### Decision 1: 編輯入口位置
**Options:**
- Option A（採用）：群組設定頁頂部名稱區旁放 `Icons.edit_outlined` icon，tap 開啟 AlertDialog
- Option B：在首頁 Header 上長按名稱可編輯

選擇 A：設定頁更符合使用者心智模型，避免誤觸。

### Decision 2: 後端實作方式
**Options:**
- Option A（採用）：直接 `UPDATE groups SET name = $name WHERE id = $groupId`，透過 RLS 驗證成員身份
- Option B：新增 Supabase RPC `update_group_name`

選擇 A：簡單且不需額外 RPC，Supabase RLS 已可處理權限。

### Risks
- **RLS 政策**：需確認 `groups` 表現有 RLS 是否允許 member UPDATE。若不允許，需新增 policy 或改用 RPC。

---

## Feature 2 — 移除群組類型 UI

### Goals
- 消除對使用者無意義的選擇
- 簡化建立流程

### Non-Goals
- 不刪除 DB 欄位（避免影響現有資料與 RPC）
- 不重新定義群組類型的語意（未來可能移作他用）

### Decision: DB 處理方式
保留 `type` 欄位，建立時固定傳 `'other'`。現有群組資料不影響。

### Risks
- **未來型別恢復**：若日後重新啟用，需重新教育使用者。低風險，接受。

---

## Feature 3 — 多幣別匯率系統

### Goals
- 分帳計算結果正確，所有金額統一以群組基礎幣別呈現
- 使用者能自行設定外幣匯率（手動輸入，不依賴外部 API）
- 未設定匯率的幣別無法在記帳時使用

### Non-Goals
- 不整合即時匯率 API（手動設定即可，保持簡單）
- 不支援「每筆記帳用不同匯率」（使用群組統一設定的匯率）
- 不支援跨群組匯率共享

### Decision 1: 匯率方向定義
**Options:**
- Option A（採用）：`rate` = 1 外幣 = N 群組基礎幣別（e.g. 1 USD = 32.5 TWD，rate = 32.5）
- Option B：反向（1 群組幣別 = N 外幣）

選擇 A：對使用者更直觀（「1 美金值多少台幣」）。

### Decision 2: 匯率儲存位置
**Options:**
- Option A（採用）：新增 `group_exchange_rates` 獨立資料表
- Option B：在 `groups` 表新增 JSONB 欄位 `exchange_rates`

選擇 A：結構化資料易於 RLS 管理、RPC JOIN、未來擴充（如加 updated_by、歷史記錄）。

### Decision 3: balance RPC 修改策略
在 `get_user_balances` 中 LEFT JOIN `group_exchange_rates`，將每筆 expense amount 乘以匯率換算為基礎幣別：
```sql
e.amount * CASE
  WHEN e.currency = g.currency THEN 1
  ELSE COALESCE(ger.rate, 1)  -- 未設定匯率時 fallback = 1（不應發生）
END
```
expense_splits 的金額亦同步換算。

### Decision 4: RLS 設計
- SELECT：group members 可讀取
- INSERT/UPDATE/DELETE：group members 皆可操作（對齊群組名稱編輯的「所有成員可改」原則）

### Risks
- **RPC 複雜度增加**：JOIN 匯率表後查詢邏輯更複雜，需完整測試混合幣別場景。
- **匯率過期**：使用者可能忘記更新匯率，導致歷史帳目換算不精確。→ 接受，MVP 不處理歷史匯率快照。
- **Hive cache**：匯率資料是新 feature，不加入離線 cache（首版僅 online 可管理匯率）。

### Migration Plan
1. 部署 Supabase migration（新表 + RLS + 更新 RPC）
2. 部署 Flutter app（新 UI + 限制幣別選擇）
3. 現有混幣記帳資料：RPC fallback `COALESCE(rate, 1)` 確保不崩潰，但計算結果可能不正確 → 使用者需補設匯率。

### Open Questions
- 是否需要在 group_settings 顯示「此群組有 N 筆使用外幣的歷史記帳，請設定匯率」的警示？（暫不實作，後續版本）
