## Context

OkaeriSplit 使用 Riverpod 做狀態管理，各 feature 的資料（群組、消費、結算）各自有 `AsyncNotifierProvider` / `FutureProvider`。登出目前只清除 Supabase session 與少數 Hive auth box，但 Riverpod provider 的 state 仍殘留，導致下一個帳號登入後看到前一帳號的資料，必須手動刷新。顯示名稱則在多處輸入欄位沒有 maxLength，Text widget 也未設定 overflow，長名稱在清單中佔滿空間。

## Goals / Non-Goals

**Goals:**
- 登出後 Riverpod state 完全重置，下一個帳號登入後保證看到自己的資料
- 登出時 Hive 快取（groups、expenses、settlements）一併清除
- 顯示名稱輸入限制 20 字元，顯示時自動截斷加省略符號

**Non-Goals:**
- 不改變登出的觸發方式或 UI 流程
- 不對其他欄位（備註、描述）加長度限制

## Decisions

### 1. 登出時使用 `ProviderContainer.invalidate` vs 重啟 App

**選擇**：在 `AuthRepository.signOut()` 完成後，由監聽 auth state 的最頂層 consumer（shell 或 main）呼叫各 provider 的 `ref.invalidate()`。

**理由**：重啟 App（`runApp` 重建）會造成視覺閃爍；直接 invalidate provider 讓 Riverpod 在下次 read 時重新 fetch，乾淨且無副作用。避免在 Repository 層直接拿 ref（違反 Clean Architecture）。

**替代方案考量**：在 `auth_repository_impl.dart` 中傳入 `Ref` 並呼叫 invalidate — 但 Repository 不應依賴 Riverpod，拒絕。

### 2. 監聽登出事件的位置

**選擇**：在 `ShellScreen`（底部導航 shell）的 `ref.listen(authStateProvider, ...)` 中偵測 `signedOut` 事件，集中呼叫各模組 provider 的 invalidate。

**理由**：Shell 已是 Riverpod widget，可自然持有 `ref`；登出後 router 會跳回 login，所以 shell 可以安全執行清除後再導航。

### 3. 顯示名稱截斷策略

**選擇**：輸入端加 `maxLength: 20`（`TextField` inputFormatters），顯示端所有 `Text(displayName)` 加 `maxLines: 1, overflow: TextOverflow.ellipsis`。

**理由**：在輸入時就限制是最簡單的防線，不需要在每個顯示點做字串截斷。

## Risks / Trade-offs

- [Risk] invalidate 時機若在 router 跳轉之前，可能出現短暫空資料畫面 → Mitigation: 先 invalidate 再 navigate，或讓 provider 在 unauthenticated 時回傳空列表
- [Risk] 漏掉部分 provider 未 invalidate → Mitigation: 建立一個統一的 `invalidateAllProviders(ref)` 函式，集中列出所有需要清除的 provider，方便日後維護

## Migration Plan

1. 在 `auth_repository_impl.dart` signOut 中補清所有 Hive box
2. 新增 `auth_invalidator.dart`（或在 shell 中）集中 invalidate 所有 provider
3. 在 ShellScreen listen auth state，signedOut 時呼叫 invalidate 函式
4. 逐一更新輸入欄位加 maxLength: 20
5. 全域搜尋顯示 display_name 的 Text widget 補上 overflow 設定
