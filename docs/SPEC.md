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

### 同步策略

| 操作 | 策略 | 說明 |
|------|------|------|
| 寫入 | Remote-first | 直接寫入 Supabase，失敗時回傳錯誤提示 |
| 讀取 | Remote-first | 直接從 Supabase 讀取，透過 Riverpod 快取 |
| 即時更新 | Supabase Realtime | 訂閱群組相關表格變更，自動 invalidate Provider |
| 離線 | 待實作（M9） | Hive 快取群組/消費；無網路可瀏覽快取 & 新增消費（pending queue），網路恢復後自動同步 |

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
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  paid_by          UUID NOT NULL REFERENCES profiles(id),
  amount           NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  currency         TEXT NOT NULL DEFAULT 'TWD',
  category         expense_category NOT NULL DEFAULT 'other',
  description      TEXT NOT NULL,
  note             TEXT,
  expense_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  attachment_urls  TEXT[],
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
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
  split_type TEXT NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'custom_ratio', 'fixed_amount', 'itemized')),
  UNIQUE (expense_id, user_id)
);

CREATE INDEX idx_expense_splits_expense_id ON expense_splits(expense_id);
```

### 2.6 `expense_items` — 項目拆分明細

```sql
CREATE TABLE expense_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id      UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  amount          NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  shared_by_users UUID[] NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_expense_items_expense_id ON expense_items(expense_id);
```

> 僅 `split_type = 'itemized'` 的消費會有對應的 expense_items 記錄。

### 2.7 `settlements` — 結算記錄

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

### 2.8 `updated_at` 自動更新

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
    │         └──< expense_items           │
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

  @override
  Future<Either<Failure, List<Expense>>> getExpenses(String groupId) async {
    try {
      final expenses = await _remote.getExpenses(groupId);
      return Right(expenses.map((m) => m.toEntity()).toList());
    } catch (e) {
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

### 6.1 寫入流程

```
使用者操作
    │
    ▼
┌──────────────┐     成功     ┌──────────────────────┐
│ 寫入 Supabase│───────────→ │ Invalidate Provider   │
│              │             │ UI 自動重新讀取         │
└──────┬───────┘             └──────────────────────┘
       │ 失敗
       ▼
┌──────────────┐
│ 回傳錯誤     │  ← SnackBar 顯示錯誤訊息
└──────────────┘
```

### 6.2 讀取流程

```
使用者請求資料（FutureProvider）
    │
    ▼
┌──────────────┐     成功     ┌──────────────┐
│ 讀取 Supabase│───────────→ │ 更新 Provider │
│              │             │ 渲染 UI       │
└──────┬───────┘             └──────────────┘
       │ 失敗
       ▼
┌──────────────┐
│ AsyncError   │  ← AppErrorWidget + retry callback
└──────────────┘
```

### 6.3 Realtime 訂閱管理

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

| 功能 | DB 表格 | API 方法 | Feature 模組 |
|------|---------|----------|-------------|
| 帳號註冊/登入 | profiles | Auth SDK | auth |
| 建立/加入群組 | groups, group_members | Client SDK + RPC | groups |
| 新增消費記錄 | expenses, expense_splits | RPC: create_expense | expenses |
| 消費分類（含自訂） | expenses.category | Client SDK | expenses |
| 均分 / 比例 / 指定金額分帳 | expense_splits | RPC: create_expense | expenses |
| 項目拆分分帳 | expense_splits, expense_items | RPC: create_expense | expenses |
| 收據附件 | Supabase Storage | uploadAttachment() | expenses |
| 欠款總覽 | — (計算) | RPC: get_user_balances | settlements |
| 手動標記已付款 | settlements | Client SDK | settlements |
| Dashboard | — (計算) | RPC: get_overall_balances | dashboard |
| 消費統計 | expenses | Client SDK (aggregate) | expenses |

---

## 8. UI Design System

### 8.1 色彩規範

| 用途 | Light | Dark |
|------|-------|------|
| Scaffold 背景 | `#F5F5F7` | `#1C1C1E` |
| 卡片 / 容器 | `#FFFFFF` | `#2C2C2E` |
| 主色 (Primary) | `#4F46E5` (Indigo) | `#4F46E5` |
| 正值 (應收/盈餘) | `#16A34A` | `#22C55E` |
| 負值 (應付/虧損) | `#DC2626` | `#EF4444` |
| 次要文字 | `#6E6E73` | `#AEAEB2` |
| 分隔線 | `rgba(0,0,0,4%)` | `rgba(255,255,255,8%)` |

### 8.2 形狀規範

| 元件 | border-radius |
|------|---------------|
| 卡片 / Section | 16px |
| 輸入框 / 按鈕 | 12px |
| Chips | 20px（全圓角）|
| 頭像 | 50%（圓形）|

### 8.3 陰影策略

不使用 box-shadow。視覺層次完全依賴背景色差：
- Scaffold 底色 `#F5F5F7` → 卡片 `#FFFFFF`（白色浮起感）
- 深色模式 `#1C1C1E` → 卡片 `#2C2C2E`

### 8.4 字體規範

| 層級 | fontSize | fontWeight | letterSpacing |
|------|----------|------------|---------------|
| 金額大字 | 48 | 700 | -1.0 |
| 大標題 | 34 | 700 | -1.0 |
| 標題 | 22 | 700 | -0.5 |
| Section 標 | 17 | 600 | -0.3 |
| Body | 15 | 400 | -0.1 |
| Caption | 13 | 400 | 0 |

### 8.5 AppBar 規範

- 背景透明，與 Scaffold 底色融合
- `elevation: 0`，`scrolledUnderElevation: 0`（捲動時不加陰影）
- 標題置中，fontSize 17 / fontWeight 600

### 8.6 NavigationBar 規範

- 背景色：`#FFFFFF` (Light) / `#2C2C2E` (Dark)
- 頂部細線分隔：`0.5px`，顏色同分隔線規範
- Indicator 色：主色 12% opacity（輕量）
- Label fontSize 11

---

## 9. 新增消費畫面 UX 規格 ✅

### 9.1 整體佈局

```
Scaffold
├── AppBar ("新增消費" / "編輯消費")
├── Column (flex)
│   ├── [A] 金額區（固定，不隨捲動）
│   └── [B] 表單主體（Expanded → ListView）
│       ├── [B1] 描述 + 分類卡
│       ├── [B2] 付款人卡
│       ├── [B3] 分攤卡（含折疊的分帳方式）
│       └── [B4] 更多選項（ExpansionTile）
└── [C] 底部送出按鈕（固定）
```

### 9.2 [A] 金額區

- 整個區塊可點擊，點擊後 focus 到隱藏 TextField，彈出系統鍵盤
- 鍵盤類型：`TextInputType.numberWithOptions(decimal: true)`
- 輸入限制：只接受數字 `[0-9]` 與一個小數點，小數點後最多 2 位
- 金額以 Display 樣式呈現（fontSize 48, fontWeight 700）
- 未輸入時顯示灰色「0」placeholder
- 左側：幣別 Chip（視覺 de-emphasize，fontSize 13，淺色邊框），點擊可換
- 送出按鈕：金額為 0 或描述空白時 disabled

### 9.3 [B1] 描述 + 分類卡

- 描述 TextField（無 border，填滿卡片內一整行）
- 細分隔線
- 分類：橫向可滑動 `ListView.builder`（非 Wrap），不換行
- 分類 Item 樣式：60×64px 圓角正方形 tile，icon 上 + label 下
  - 未選中：白底 or 淺灰底、深色 icon
  - 選中：主色填底、白色 icon + 白色文字
- 最右側固定顯示「+ 自訂」按鈕（不捲動消失）

### 9.4 [B2] 付款人卡

- Section title「誰付的錢」
- 橫向 Wrap，每個成員顯示為「頭像 + 姓名」Chip（單選）
- 選中狀態：主色邊框 + ✓ badge
- 未選中狀態：灰色邊框

### 9.5 [B3] 分攤卡

**成員選擇區**
- Section title「分攤成員」
- 橫向 Wrap，每個成員顯示為「頭像 + 姓名」Chip（多選，最少 1 人）
- 選中狀態：主色填底、白字
- 未選中：淺灰底

**即時摘要文字**（在 chips 下方）
- 均分：「平均分給 N 人，每人 $X.XX」
- 自訂比例：「依比例分配 (A:B:C)」
- 指定金額：驗證中或已符合/差額提示
- 項目拆分：「共 N 個品項」

**分帳方式 ExpansionTile**（預設折疊）
- 折疊時 header 顯示：「分帳方式：[目前模式名稱]」
  - 均分 → 不特別標示（或顯示「均分」）
  - 非均分 → 顯示「自訂比例 (2:1:1)」/ 「指定金額」/ 「項目拆分」
- 展開後：RadioListTile 選擇模式（均分 / 自訂比例 / 指定金額 / 項目拆分）
- 選中非均分後，在 RadioListTile 下方 inline 展開對應的輸入 UI

### 9.6 [B4] 更多選項（ExpansionTile）

預設折疊；若為編輯模式且 `note != null || attachmentUrls.isNotEmpty` 則預設展開。

展開後包含：
- 📅 **日期**：顯示目前日期，點擊打開 `showDatePicker`
- 📝 **備註**：多行 TextField（maxLines: 2），選填
- 📎 **收據/照片**：Wrap 縮圖 + 新增按鈕（拍照 / 相簿）

### 9.7 [C] 底部送出按鈕

- `FilledButton`，固定在 `SafeArea` 內底部
- 文字：「新增消費」/ 「儲存變更」
- Disabled 條件：金額 ≤ 0 **或** 描述空白
- Loading 狀態：顯示 `CircularProgressIndicator(strokeWidth: 2)`

---

## 10. iOS Home Widget 規格

### 10.1 功能定位

- 使用者在桌面不打開 App 即可看到自己的群組清單
- 點擊 [+ 記帳] → 深度連結開啟 App 並跳到該群組的 AddExpenseScreen
- 僅支援 iOS（WidgetKit，Medium size）

### 10.2 技術架構

```
Flutter App ──寫入──▶ App Group UserDefaults ◀──讀取── WidgetKit Extension (Swift)
     │                                                          │
     │                                              顯示群組清單 + 按鈕
     │
     ◀──URL Scheme────────────────────────────── 使用者點擊按鈕
  app_links 攔截
  GoRouter 導航至 /groups/:id/add-expense
```

### 10.3 元件清單

| 元件 | 位置 | 說明 |
|------|------|------|
| `home_widget` 套件 | pubspec.yaml | Flutter ↔ Native 橋接 |
| `app_links` 套件 | pubspec.yaml | 深度連結攔截（URL scheme 已存在） |
| Widget Extension | ios/OkaeriSplitWidget/ | Swift WidgetKit Extension |
| App Group | Xcode Capabilities | 共享 UserDefaults 容器（`group.com.raycat.okaerisplit`） |
| `HomeWidgetService` | lib/core/services/ | Flutter 端寫入 App Group 的 service |

### 10.4 App Group 資料格式

Flutter 在以下時機將資料寫入 App Group UserDefaults：
- App 啟動時
- `groupsProvider` 資料更新時

```json
{
  "groups": [
    { "id": "uuid-1", "name": "旅行群組", "currency": "TWD" },
    { "id": "uuid-2", "name": "室友群組", "currency": "TWD" }
  ],
  "lastUpdated": "2026-03-11T10:00:00Z"
}
```

### 10.5 Widget UI（Medium size，SwiftUI）

```
┌──────────────────────────────┐
│  OkaeriSplit    [圖示]        │
│  ────────────────────────── │
│  旅行群組   TWD    [+ 記帳]   │
│  室友群組   TWD    [+ 記帳]   │
│  活動群組   TWD    [+ 記帳]   │
└──────────────────────────────┘
```

- 最多顯示 3 組（Medium size），超過顯示「...」
- 無群組時顯示「開啟 App 建立群組」
- [+ 記帳] 按鈕觸發 URL：`com.raycat.okaerisplit://add-expense?groupId=<id>`

### 10.6 Deep Link 處理（Flutter 端）

URL scheme `com.raycat.okaerisplit://` 已在 Info.plist 註冊（auth 用）。新增 `/add-expense` path 的處理：

```
app_links 監聽 → AppRouter 解析 URL
  com.raycat.okaerisplit://add-expense?groupId=xxx
  → context.push('/groups/xxx/add-expense')
```

### 10.7 HomeWidgetService 介面（Dart）

```dart
class HomeWidgetService {
  static const _appGroupId = 'group.com.raycat.okaerisplit';

  Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// 將群組列表寫入 App Group UserDefaults（Widget 讀取用）
  Future<void> updateGroups(List<GroupEntity> groups) async {
    final payload = {
      'groups': groups.take(3).map((g) => {
        'id': g.id,
        'name': g.name,
        'currency': g.currency,
      }).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await HomeWidget.saveWidgetData('groups_payload', jsonEncode(payload));
    await HomeWidget.updateWidget(
      iOSName: 'OkaeriSplitWidget',
    );
  }
}
```

### 10.8 iOS 設定步驟（需手動）

1. Xcode → File → New → Target → Widget Extension（命名 `OkaeriSplitWidget`）
2. Runner + OkaeriSplitWidget 皆加入同一 App Group：`group.com.raycat.okaerisplit`
3. Swift Widget 程式碼從 App Group UserDefaults 讀取群組列表，渲染 SwiftUI View
4. Flutter `home_widget` 初始化時呼叫 `HomeWidget.setAppGroupId('group.com.raycat.okaerisplit')`

---

## 11. 離線記帳與自動同步規格

### 11.1 功能定位

- 無網路時仍可新增消費（存本地），並可瀏覽上次快取的群組/消費列表
- 網路恢復後自動將待同步消費上傳 Supabase
- 消費列表 AppBar 顯示「待同步 N 筆」Badge

### 11.2 技術架構

```
有網路時：
  Supabase ──讀取──▶ Riverpod Provider ──渲染──▶ UI
                          │
                          └──寫入──▶ Hive Cache（自動更新）

無網路時：
  Hive Cache ──讀取──▶ Riverpod Provider ──渲染──▶ UI（顯示快取資料）

新增消費（無網路）：
  UI ──▶ PendingExpenseRepository ──寫入──▶ Hive pending_expenses box

網路恢復：
  ConnectivityService 偵測 ──▶ SyncService.flush() ──▶ Supabase
                                                       ──▶ invalidate Providers
```

### 11.3 新增套件

| 套件 | 用途 |
|------|------|
| `connectivity_plus` | 監聽網路連線狀態 |

### 11.4 Hive Box 結構

Hive 已安裝，新增以下 Box：

| Box 名稱 | 資料型態 | 說明 |
|----------|----------|------|
| `groups_cache` | JSON string | 群組列表快取 |
| `expenses_cache` | JSON string（key: groupId） | 各群組消費列表快取 |
| `group_members_cache` | JSON string（key: groupId） | 成員列表快取（離線新增消費時需要） |
| `pending_expenses` | JSON string list | 待上傳的消費佇列 |

### 11.5 PendingExpenseDto 資料結構

```dart
class PendingExpenseDto {
  final String localId;      // UUID，本地暫時 ID
  final String groupId;
  final String paidBy;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final String? note;
  final DateTime expenseDate;
  final List<Map<String, dynamic>> splits;
  final DateTime pendingAt;
}
```

### 11.6 元件清單

| 元件 | 位置 | 說明 |
|------|------|------|
| `ConnectivityService` | lib/core/services/ | 監聽連線狀態，提供 `isOnline` stream |
| `connectivityProvider` | lib/core/providers/ | Riverpod 包裝 ConnectivityService |
| `SyncService` | lib/core/services/ | 處理 pending_expenses 上傳佇列 |
| `PendingExpenseRepository` | lib/features/expenses/data/ | 讀寫 Hive pending_expenses box |
| `HiveGroupDataSource` | lib/features/groups/data/datasources/ | 快取群組列表（已存在但空白） |
| `HiveExpenseDataSource` | lib/features/expenses/data/datasources/ | 快取消費列表 |

### 11.7 Repository 讀取邏輯

**GroupRepositoryImpl**（讀取）:
```
isOnline?
  ├── 是 → 讀 Supabase → 寫 Hive cache → 回傳
  └── 否 → 讀 Hive cache（無快取則回傳空列表 + offline 標記）
```

**ExpenseRepositoryImpl**（讀取）:
```
isOnline?
  ├── 是 → 讀 Supabase → 寫 Hive cache → 回傳
  └── 否 → 讀 Hive cache（無快取則回傳空列表 + offline 標記）
```

**ExpenseRepositoryImpl**（新增消費）:
```
isOnline?
  ├── 是 → 直接送 Supabase RPC → 完成
  └── 否 → 存入 Hive pending_expenses → 回傳成功（UI 顯示「已離線儲存」）
```

### 11.8 SyncService 流程

```dart
// 網路恢復時觸發
Future<void> flush() async {
  final pending = await _pendingRepo.getAll();
  for (final item in pending) {
    try {
      await _supabaseDs.createExpense(/* item 資料 */);
      await _pendingRepo.remove(item.localId);
    } catch (e) {
      // 保留，下次再試
    }
  }
  // 完成後 invalidate providers
}
```

### 11.9 UI 變更

- **ExpenseListScreen AppBar**：當 `pendingCount > 0` 時顯示 `待同步 N 筆` 的小 Chip（`pendingSyncBadge`）
- **新增消費成功（離線）**：SnackBar 顯示「已離線儲存，稍後將自動同步」
- **離線時新增消費**：付款人 / 分攤成員從 `group_members_cache` 讀取，其餘流程與線上相同
