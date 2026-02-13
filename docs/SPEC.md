# OkaeriSplit 技術規格文件（Technical Specification）

## 1. 系統架構總覽

```
┌─────────────────────────────────────────────────┐
│                 Flutter App                      │
│  ┌───────────┐  ┌───────────┐  ┌─────────────┐  │
│  │Presentation│  │  Domain   │  │    Data     │  │
│  │ (Riverpod) │→ │(Use Cases)│→ │(Repository) │  │
│  └───────────┘  └───────────┘  └──────┬──────┘  │
│                                       │          │
│                    ┌──────────────────┼────────┐ │
│                    │                  │        │ │
│               ┌────▼────┐      ┌─────▼─────┐  │ │
│               │  Hive   │      │ Supabase  │  │ │
│               │ (本地)   │      │  Client   │  │ │
│               └─────────┘      └─────┬─────┘  │ │
│                                      │         │ │
└──────────────────────────────────────┼─────────┘ │
                                       │
                          ┌────────────▼──────────┐
                          │      Supabase          │
                          │  ┌──────────────────┐  │
                          │  │   Auth (GoTrue)   │  │
                          │  ├──────────────────┤  │
                          │  │   Realtime        │  │
                          │  ├──────────────────┤  │
                          │  │   Storage         │  │
                          │  └──────────────────┘  │
                          │          │              │
                          │  ┌───────▼──────────┐  │
                          │  │   PostgreSQL      │  │
                          │  │   + RLS Policy    │  │
                          │  └──────────────────┘  │
                          └────────────────────────┘
```

### 離線架構

| 操作 | 策略 | 說明 |
|------|------|------|
| 寫入 | Local-first | 先寫 Hive，標記 `pending_sync`，背景同步至 Supabase |
| 讀取 | Remote-first, local-fallback | 優先從 Supabase 讀取，失敗時降級使用 Hive 快取 |
| 即時更新 | Supabase Realtime | 訂閱群組相關表格變更，推送更新至本地 |
| 衝突處理 | Last-write-wins | 以 `updated_at` 時間戳為準，伺服器端為最終權威 |

---

## 2. DB Schema（Supabase / PostgreSQL）

### 2.1 `profiles` — 使用者資料

```sql
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_url  TEXT,
  email       TEXT NOT NULL,
  default_currency TEXT NOT NULL DEFAULT 'TWD',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 新使用者註冊時自動建立 profile
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

### 2.2 `groups` — 群組

```sql
CREATE TABLE groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('roommate', 'travel', 'event')),
  currency    TEXT NOT NULL DEFAULT 'TWD',
  invite_code TEXT UNIQUE NOT NULL DEFAULT substr(md5(random()::text), 1, 6),
  created_by  UUID NOT NULL REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_groups_invite_code ON groups(invite_code);
```

### 2.3 `group_members` — 群組成員

```sql
CREATE TABLE group_members (
  group_id  UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);
```

### 2.4 `expenses` — 消費記錄

```sql
CREATE TYPE expense_category AS ENUM (
  'food', 'transport', 'accommodation',
  'entertainment', 'daily_necessities', 'other'
);

CREATE TABLE expenses (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  paid_by      UUID NOT NULL REFERENCES profiles(id),
  amount       NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  currency     TEXT NOT NULL DEFAULT 'TWD',
  category     expense_category NOT NULL DEFAULT 'other',
  description  TEXT NOT NULL,
  note         TEXT,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_expenses_group_id ON expenses(group_id);
CREATE INDEX idx_expenses_paid_by ON expenses(paid_by);
```

### 2.5 `expense_splits` — 分帳明細

```sql
CREATE TABLE expense_splits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id),
  amount     NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  split_type TEXT NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'custom_ratio', 'fixed_amount')),
  UNIQUE (expense_id, user_id)
);

CREATE INDEX idx_expense_splits_expense_id ON expense_splits(expense_id);
```

### 2.6 `settlements` — 結算記錄

```sql
CREATE TABLE settlements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  from_user  UUID NOT NULL REFERENCES profiles(id),
  to_user    UUID NOT NULL REFERENCES profiles(id),
  amount     NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  currency   TEXT NOT NULL DEFAULT 'TWD',
  settled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (from_user <> to_user)
);

CREATE INDEX idx_settlements_group_id ON settlements(group_id);
```

### 2.7 `updated_at` 自動更新

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### ER Diagram

```
profiles ──────< group_members >────── groups
    │                                      │
    │                                      │
    ├──< expenses ──< expense_splits       │
    │                                      │
    └──< settlements (from/to) >───────────┘
```

---

## 3. RLS（Row Level Security）政策

所有表格啟用 RLS：

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
```

### 共用輔助函式

```sql
-- 判斷使用者是否為群組成員
CREATE OR REPLACE FUNCTION is_group_member(gid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = gid AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;
```

### 各表 RLS 政策

#### profiles

```sql
-- 任何已登入使用者都可讀取（群組內需顯示其他成員資料）
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT TO authenticated USING (true);

-- 只能修改自己的 profile
CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE TO authenticated USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
```

#### groups

```sql
-- 群組成員可讀取
CREATE POLICY "groups_select" ON groups
  FOR SELECT TO authenticated USING (is_group_member(id));

-- 已登入使用者可建立群組
CREATE POLICY "groups_insert" ON groups
  FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());

-- 群組 owner 可更新
CREATE POLICY "groups_update" ON groups
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = id AND user_id = auth.uid() AND role = 'owner'
    )
  );
```

#### group_members

```sql
-- 群組成員可讀取成員列表
CREATE POLICY "group_members_select" ON group_members
  FOR SELECT TO authenticated USING (is_group_member(group_id));

-- 透過 RPC join_group_by_code 處理加入（SECURITY DEFINER）
CREATE POLICY "group_members_insert" ON group_members
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- 成員可自行退出群組（owner 不可退出，需先轉移 ownership）
CREATE POLICY "group_members_delete" ON group_members
  FOR DELETE TO authenticated USING (
    user_id = auth.uid()
    AND role <> 'owner'
  );
```

#### expenses

```sql
-- 群組成員可讀取
CREATE POLICY "expenses_select" ON expenses
  FOR SELECT TO authenticated USING (is_group_member(group_id));

-- 群組成員可新增（paid_by 不限於自己，可代付）
CREATE POLICY "expenses_insert" ON expenses
  FOR INSERT TO authenticated WITH CHECK (is_group_member(group_id));

-- 建立者可更新/刪除
CREATE POLICY "expenses_update" ON expenses
  FOR UPDATE TO authenticated USING (paid_by = auth.uid());

CREATE POLICY "expenses_delete" ON expenses
  FOR DELETE TO authenticated USING (paid_by = auth.uid());
```

#### expense_splits

```sql
-- 同 expense 的存取權限
CREATE POLICY "expense_splits_select" ON expense_splits
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND is_group_member(e.group_id)
    )
  );

CREATE POLICY "expense_splits_insert" ON expense_splits
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND is_group_member(e.group_id)
    )
  );

-- 消費建立者可更新/刪除 splits（與 expenses 權限一致）
CREATE POLICY "expense_splits_update" ON expense_splits
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND e.paid_by = auth.uid()
    )
  );

CREATE POLICY "expense_splits_delete" ON expense_splits
  FOR DELETE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_id AND e.paid_by = auth.uid()
    )
  );
```

#### settlements

```sql
-- 群組成員可讀取
CREATE POLICY "settlements_select" ON settlements
  FOR SELECT TO authenticated USING (is_group_member(group_id));

-- 付款方可建立結算記錄
CREATE POLICY "settlements_insert" ON settlements
  FOR INSERT TO authenticated WITH CHECK (
    from_user = auth.uid() AND is_group_member(group_id)
  );
```

---

## 4. API 設計

MVP 階段直接使用 Supabase Client SDK 進行 CRUD，複雜計算透過 PostgreSQL RPC 實現。

### 4.1 Supabase Client 直接操作

| 操作 | 方法 | 說明 |
|------|------|------|
| 註冊 | `supabase.auth.signUp()` | Email + password |
| Google 登入 | `supabase.auth.signInWithOAuth()` | provider: google |
| Apple 登入 | `supabase.auth.signInWithOAuth()` | provider: apple |
| 讀取 profile | `supabase.from('profiles').select().eq('id', uid)` | |
| 更新 profile | `supabase.from('profiles').update({...}).eq('id', uid)` | |
| 建立群組 | `supabase.rpc('create_group', {...})` | Transaction 同時建立 groups + group_members(owner) |
| 讀取群組列表 | `supabase.from('group_members').select('*, groups(*)')` | 透過 join 取得群組資訊 |
| 新增消費 | `supabase.rpc('create_expense', {...})` | Transaction 同時建立 expenses + expense_splits |
| 讀取群組消費 | `supabase.from('expenses').select('*, expense_splits(*)')` | 含分帳明細 |
| 標記已付款 | `supabase.from('settlements').insert({...})` | |
| 讀取結算記錄 | `supabase.from('settlements').select()` | |

### 4.2 RPC（PostgreSQL Functions）

#### `create_group(p_name TEXT, p_type TEXT, p_currency TEXT)`

在 transaction 中同時建立群組與 owner 成員記錄，確保資料一致性。invite_code 碰撞時自動 retry。

```sql
CREATE OR REPLACE FUNCTION create_group(
  p_name TEXT,
  p_type TEXT,
  p_currency TEXT DEFAULT 'TWD'
)
RETURNS UUID AS $$
DECLARE
  v_group_id UUID;
  v_invite_code TEXT;
  v_retry INT := 0;
BEGIN
  LOOP
    v_invite_code := substr(md5(random()::text), 1, 6);
    BEGIN
      INSERT INTO groups (name, type, currency, invite_code, created_by)
      VALUES (p_name, p_type, p_currency, v_invite_code, auth.uid())
      RETURNING id INTO v_group_id;
      EXIT; -- 成功則跳出 loop
    EXCEPTION WHEN unique_violation THEN
      v_retry := v_retry + 1;
      IF v_retry > 5 THEN
        RAISE EXCEPTION 'Failed to generate unique invite code';
      END IF;
    END;
  END LOOP;

  INSERT INTO group_members (group_id, user_id, role)
  VALUES (v_group_id, auth.uid(), 'owner');

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `create_expense(p_group_id UUID, p_paid_by UUID, p_amount NUMERIC, p_currency TEXT, p_category expense_category, p_description TEXT, p_note TEXT, p_expense_date DATE, p_splits JSONB)`

在 transaction 中同時建立消費記錄與分帳明細，避免只寫入一半。`p_splits` 格式為 `[{"user_id": "...", "amount": 100, "split_type": "equal"}, ...]`。

```sql
CREATE OR REPLACE FUNCTION create_expense(
  p_group_id UUID,
  p_paid_by UUID,
  p_amount NUMERIC,
  p_currency TEXT,
  p_category expense_category,
  p_description TEXT,
  p_note TEXT DEFAULT NULL,
  p_expense_date DATE DEFAULT CURRENT_DATE,
  p_splits JSONB DEFAULT '[]'
)
RETURNS UUID AS $$
DECLARE
  v_expense_id UUID;
  v_split JSONB;
BEGIN
  -- 驗證呼叫者為群組成員
  IF NOT is_group_member(p_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  INSERT INTO expenses (group_id, paid_by, amount, currency, category, description, note, expense_date)
  VALUES (p_group_id, p_paid_by, p_amount, p_currency, p_category, p_description, p_note, p_expense_date)
  RETURNING id INTO v_expense_id;

  FOR v_split IN SELECT * FROM jsonb_array_elements(p_splits)
  LOOP
    INSERT INTO expense_splits (expense_id, user_id, amount, split_type)
    VALUES (
      v_expense_id,
      (v_split->>'user_id')::UUID,
      (v_split->>'amount')::NUMERIC,
      COALESCE(v_split->>'split_type', 'equal')
    );
  END LOOP;

  RETURN v_expense_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `get_user_balances(p_group_id UUID)`

計算群組內每位成員的淨欠款。

```sql
CREATE OR REPLACE FUNCTION get_user_balances(p_group_id UUID)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  total_paid NUMERIC,
  total_owed NUMERIC,
  net_balance NUMERIC  -- 正數=別人欠你，負數=你欠別人
) AS $$
BEGIN
  RETURN QUERY
  WITH paid AS (
    SELECT e.paid_by AS uid, COALESCE(SUM(e.amount), 0) AS total
    FROM expenses e
    WHERE e.group_id = p_group_id
    GROUP BY e.paid_by
  ),
  owed AS (
    SELECT es.user_id AS uid, COALESCE(SUM(es.amount), 0) AS total
    FROM expense_splits es
    JOIN expenses e ON e.id = es.expense_id
    WHERE e.group_id = p_group_id
    GROUP BY es.user_id
  ),
  settled_out AS (
    SELECT s.from_user AS uid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.group_id = p_group_id
    GROUP BY s.from_user
  ),
  settled_in AS (
    SELECT s.to_user AS uid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.group_id = p_group_id
    GROUP BY s.to_user
  )
  SELECT
    gm.user_id,
    p.display_name,
    p.avatar_url,
    COALESCE(pd.total, 0) AS total_paid,
    COALESCE(ow.total, 0) AS total_owed,
    COALESCE(pd.total, 0) - COALESCE(ow.total, 0)
      + COALESCE(so.total, 0) - COALESCE(si.total, 0) AS net_balance
  FROM group_members gm
  JOIN profiles p ON p.id = gm.user_id
  LEFT JOIN paid pd ON pd.uid = gm.user_id
  LEFT JOIN owed ow ON ow.uid = gm.user_id
  LEFT JOIN settled_out so ON so.uid = gm.user_id
  LEFT JOIN settled_in si ON si.uid = gm.user_id
  WHERE gm.group_id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
```

#### `get_overall_balances(p_user_id UUID)`

跨群組個人帳務總覽。

```sql
CREATE OR REPLACE FUNCTION get_overall_balances(p_user_id UUID)
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  net_balance NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH paid AS (
    SELECT e.group_id AS gid, COALESCE(SUM(e.amount), 0) AS total
    FROM expenses e
    WHERE e.paid_by = p_user_id
    GROUP BY e.group_id
  ),
  owed AS (
    SELECT e.group_id AS gid, COALESCE(SUM(es.amount), 0) AS total
    FROM expense_splits es
    JOIN expenses e ON e.id = es.expense_id
    WHERE es.user_id = p_user_id
    GROUP BY e.group_id
  ),
  settled_out AS (
    SELECT s.group_id AS gid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.from_user = p_user_id
    GROUP BY s.group_id
  ),
  settled_in AS (
    SELECT s.group_id AS gid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.to_user = p_user_id
    GROUP BY s.group_id
  )
  SELECT
    g.id,
    g.name,
    COALESCE(pd.total, 0) - COALESCE(ow.total, 0)
      + COALESCE(so.total, 0) - COALESCE(si.total, 0) AS net_balance
  FROM group_members gm
  JOIN groups g ON g.id = gm.group_id
  LEFT JOIN paid pd ON pd.gid = g.id
  LEFT JOIN owed ow ON ow.gid = g.id
  LEFT JOIN settled_out so ON so.gid = g.id
  LEFT JOIN settled_in si ON si.gid = g.id
  WHERE gm.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
```

#### `join_group_by_code(p_invite_code TEXT)`

透過邀請碼加入群組。

```sql
CREATE OR REPLACE FUNCTION join_group_by_code(p_invite_code TEXT)
RETURNS UUID AS $$
DECLARE
  v_group_id UUID;
BEGIN
  SELECT id INTO v_group_id
  FROM groups
  WHERE invite_code = p_invite_code;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  INSERT INTO group_members (group_id, user_id, role)
  VALUES (v_group_id, auth.uid(), 'member')
  ON CONFLICT (group_id, user_id) DO NOTHING;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 4.3 Supabase Realtime 訂閱

```dart
// 訂閱群組消費變更
supabase.from('expenses')
  .stream(primaryKey: ['id'])
  .eq('group_id', groupId)
  .listen((data) { /* 更新本地狀態 */ });

// 訂閱群組成員變更
supabase.from('group_members')
  .stream(primaryKey: ['group_id', 'user_id'])
  .eq('group_id', groupId)
  .listen((data) { /* 更新成員列表 */ });
```

---

## 5. Flutter 應用架構

### 5.1 Feature 模組

```
lib/
├── core/
│   ├── constants/        # 常數定義（API URL、enum 映射）
│   ├── errors/           # 錯誤類型（Failure class, Either typedef）
│   ├── extensions/       # Dart 擴充方法
│   ├── theme/            # 主題設定（light/dark, Cupertino 支援）
│   ├── utils/            # 工具函式
│   └── widgets/          # 共用 Widget
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/    # SupabaseAuthDataSource
│   │   │   └── repositories/   # AuthRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/       # User
│   │   │   ├── repositories/   # AuthRepository (abstract)
│   │   │   └── usecases/       # SignIn, SignUp, SignOut
│   │   └── presentation/
│   │       ├── providers/      # authProvider, authStateProvider
│   │       ├── screens/        # LoginScreen, RegisterScreen
│   │       └── widgets/        # SocialLoginButton
│   ├── groups/
│   │   ├── data/
│   │   │   ├── datasources/    # SupabaseGroupDataSource, HiveGroupDataSource
│   │   │   ├── models/         # GroupModel (freezed)
│   │   │   └── repositories/   # GroupRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/       # Group, GroupMember
│   │   │   ├── repositories/   # GroupRepository (abstract)
│   │   │   └── usecases/       # CreateGroup, JoinGroup, GetGroups
│   │   └── presentation/
│   │       ├── providers/      # groupsProvider, groupDetailProvider
│   │       ├── screens/        # GroupListScreen, GroupDetailScreen, CreateGroupScreen
│   │       └── widgets/        # GroupCard, MemberAvatar
│   ├── expenses/
│   │   ├── data/
│   │   │   ├── datasources/    # SupabaseExpenseDataSource, HiveExpenseDataSource
│   │   │   ├── models/         # ExpenseModel, ExpenseSplitModel (freezed)
│   │   │   └── repositories/   # ExpenseRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/       # Expense, ExpenseSplit
│   │   │   ├── repositories/   # ExpenseRepository (abstract)
│   │   │   └── usecases/       # AddExpense, GetExpenses, DeleteExpense
│   │   └── presentation/
│   │       ├── providers/      # expensesProvider, addExpenseProvider
│   │       ├── screens/        # ExpenseListScreen, AddExpenseScreen
│   │       └── widgets/        # ExpenseCard, SplitMethodSelector, CategoryPicker
│   ├── settlements/
│   │   ├── data/
│   │   │   ├── datasources/    # SupabaseSettlementDataSource
│   │   │   ├── models/         # SettlementModel (freezed)
│   │   │   └── repositories/   # SettlementRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/       # Settlement, Balance
│   │   │   ├── repositories/   # SettlementRepository (abstract)
│   │   │   └── usecases/       # GetBalances, MarkSettled
│   │   └── presentation/
│   │       ├── providers/      # balancesProvider, settlementsProvider
│   │       ├── screens/        # BalanceScreen, SettlementHistoryScreen
│   │       └── widgets/        # BalanceCard, DebtRow
│   └── dashboard/
│       └── presentation/
│           ├── providers/      # overallBalanceProvider
│           ├── screens/        # DashboardScreen
│           └── widgets/        # BalanceSummaryCard, RecentExpenseList
├── routing/
│   └── app_router.dart         # GoRouter 設定
└── main.dart
```

### 5.2 Data Layer 模式

```dart
// 1. Model（freezed data class）
@freezed
class ExpenseModel with _$ExpenseModel {
  const factory ExpenseModel({
    required String id,
    required String groupId,
    required String paidBy,
    required double amount,
    required String currency,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ExpenseModel;

  factory ExpenseModel.fromJson(Map<String, dynamic> json) =>
      _$ExpenseModelFromJson(json);
}

// 2. Data Source（abstract + implementation）
abstract class ExpenseRemoteDataSource {
  Future<List<ExpenseModel>> getExpenses(String groupId);
  Future<ExpenseModel> addExpense(ExpenseModel expense);
  Future<void> deleteExpense(String id);
}

// 3. Repository Implementation
class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseRemoteDataSource _remote;
  final ExpenseLocalDataSource _local;

  @override
  Future<Either<Failure, List<Expense>>> getExpenses(String groupId) async {
    try {
      final expenses = await _remote.getExpenses(groupId);
      await _local.cacheExpenses(groupId, expenses);
      return Right(expenses.map((m) => m.toEntity()).toList());
    } catch (e) {
      // fallback to local cache
      final cached = await _local.getCachedExpenses(groupId);
      if (cached != null) return Right(cached);
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

### 5.3 Riverpod Provider 架構

```dart
// Data Source providers
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Repository providers
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(
    remote: ref.watch(expenseRemoteDataSourceProvider),
    local: ref.watch(expenseLocalDataSourceProvider),
  );
});

// Use Case providers
final getExpensesUseCaseProvider = Provider<GetExpenses>((ref) {
  return GetExpenses(ref.watch(expenseRepositoryProvider));
});

// State providers (UI)
final expensesProvider = FutureProvider.family<List<Expense>, String>(
  (ref, groupId) async {
    final useCase = ref.watch(getExpensesUseCaseProvider);
    final result = await useCase(groupId);
    return result.fold(
      (failure) => throw failure,
      (expenses) => expenses,
    );
  },
);
```

### 5.4 路由結構（go_router）

```dart
final appRouter = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final isLoggedIn = /* check auth state */;
    if (!isLoggedIn) return '/login';
    return null;
  },
  routes: [
    // Auth
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

    // Main (with bottom navigation shell)
    ShellRoute(
      builder: (_, __, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (_, __) => const GroupListScreen(),
          routes: [
            GoRoute(
              path: 'create',
              builder: (_, __) => const CreateGroupScreen(),
            ),
            GoRoute(
              path: ':groupId',
              builder: (_, state) => GroupDetailScreen(
                groupId: state.pathParameters['groupId']!,
              ),
              routes: [
                GoRoute(
                  path: 'add-expense',
                  builder: (_, state) => AddExpenseScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                GoRoute(
                  path: 'balances',
                  builder: (_, state) => BalanceScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
```

### 5.5 底部導航

| Tab | 路由 | 畫面 |
|-----|------|------|
| Dashboard | `/dashboard` | 個人帳務總覽 |
| 群組 | `/groups` | 群組列表 |
| 我的 | `/profile` | 個人設定 |

---

## 6. 資料流與同步策略

### 6.1 寫入流程（Local-first）

```
使用者操作
    │
    ▼
┌─────────────┐
│ 寫入 Hive   │  ← 立即完成，UI 即時反應
│ pending_sync │
└──────┬──────┘
       │ (背景)
       ▼
┌──────────────┐     成功     ┌──────────────┐
│ 同步 Supabase │───────────→│ 移除 pending  │
│              │             │ 更新本地資料   │
└──────┬───────┘             └──────────────┘
       │ 失敗
       ▼
┌──────────────┐
│ 保留 pending │  ← 下次上線時重試
│ 排程重試     │
└──────────────┘
```

### 6.2 讀取流程（Remote-first）

```
使用者請求資料
    │
    ▼
┌──────────────┐     成功     ┌──────────────┐
│ 讀取 Supabase │───────────→│ 更新 Hive 快取│
│              │             │ 回傳資料      │
└──────┬───────┘             └──────────────┘
       │ 失敗 (離線)
       ▼
┌──────────────┐
│ 讀取 Hive    │  ← 降級使用本地快取
│ 顯示離線提示  │
└──────────────┘
```

### 6.3 Hive Box 結構

| Box 名稱 | Key | Value | 說明 |
|----------|-----|-------|------|
| `groups` | groupId | GroupModel JSON | 群組資料快取 |
| `expenses_{groupId}` | expenseId | ExpenseModel JSON | 群組消費快取 |
| `balances_{groupId}` | `balances` | List\<BalanceModel\> JSON | 餘額快取 |
| `pending_sync` | auto-increment | SyncOperation JSON | 待同步操作佇列 |
| `user_profile` | `profile` | ProfileModel JSON | 使用者資料快取 |

### 6.4 SyncOperation 結構

```dart
@freezed
class SyncOperation with _$SyncOperation {
  const factory SyncOperation({
    required String id,
    required String table,       // 'expenses', 'settlements', etc.
    required String operation,   // 'insert', 'update', 'delete'
    required Map<String, dynamic> data,
    required DateTime createdAt,
    @Default(0) int retryCount,
  }) = _SyncOperation;
}
```

### 6.5 Realtime 訂閱管理

進入群組詳情頁時啟動訂閱，離開時取消：

```dart
// 在 GroupDetailScreen 的 provider 中管理
final groupRealtimeProvider = StreamProvider.family<void, String>(
  (ref, groupId) {
    final supabase = ref.watch(supabaseClientProvider);

    final expenseChannel = supabase
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId);

    return expenseChannel.map((data) {
      // 更新本地 Hive 快取
      // 觸發 UI 重新渲染
      ref.invalidate(expensesProvider(groupId));
    });
  },
);
```

---

## 7. MVP 功能與技術對照

| PRD P0 功能 | DB 表格 | API 方法 | Feature 模組 |
|-------------|---------|----------|-------------|
| 帳號註冊/登入 | profiles | Auth SDK | auth |
| 建立/加入群組 | groups, group_members | Client SDK + RPC | groups |
| 新增消費記錄 | expenses, expense_splits | Client SDK | expenses |
| 消費分類 | expenses.category | Client SDK | expenses |
| 均分分帳 | expense_splits | Client SDK | expenses |
| 欠款總覽 | — (計算) | RPC: get_user_balances | settlements |
| 手動標記已付款 | settlements | Client SDK | settlements |
| 基本 Dashboard | — (計算) | RPC: get_overall_balances | dashboard |
