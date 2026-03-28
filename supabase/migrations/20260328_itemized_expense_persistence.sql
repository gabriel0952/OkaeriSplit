-- Standalone itemized split persistence migration.
--
-- This migration intentionally supersedes the older
-- 20260214_add_itemized_split.sql schema-only step by:
--   1) backfilling the itemized split constraint / expense_items table if missing
--   2) preserving idempotency for environments that already applied 20260214
--   3) wiring create_expense / update_expense so app writes actually persist
--
-- In short:
-- - 20260214 = legacy schema-only rollout
-- - 20260328 = current source of truth for runnable itemized persistence

-- Persist itemized expense rows alongside aggregated expense_splits.

ALTER TABLE expense_splits
  DROP CONSTRAINT IF EXISTS expense_splits_split_type_check;

ALTER TABLE expense_splits
  ADD CONSTRAINT expense_splits_split_type_check
  CHECK (split_type IN ('equal', 'custom_ratio', 'fixed_amount', 'itemized'));

CREATE TABLE IF NOT EXISTS expense_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  shared_by_user_ids UUID[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expense_items_expense_id
  ON expense_items(expense_id);

ALTER TABLE expense_items ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'expense_items'
      AND policyname = 'Group members can manage expense items'
  ) THEN
    CREATE POLICY "Group members can manage expense items"
      ON expense_items FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM expenses e
          JOIN group_members gm ON gm.group_id = e.group_id
          WHERE e.id = expense_items.expense_id
            AND gm.user_id = auth.uid()
        )
      );
  END IF;
END;
$$;

DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT p.oid, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'create_expense'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS public.create_expense(%s)', fn.args);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_expense(
  p_group_id UUID,
  p_paid_by UUID,
  p_amount NUMERIC,
  p_currency TEXT,
  p_category TEXT,
  p_description TEXT,
  p_note TEXT DEFAULT NULL,
  p_expense_date DATE DEFAULT CURRENT_DATE,
  p_splits JSONB DEFAULT '[]',
  p_items JSONB DEFAULT '[]'
)
RETURNS UUID AS $$
DECLARE
  v_expense_id UUID;
  v_split JSONB;
  v_item JSONB;
BEGIN
  IF NOT is_group_member(p_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  INSERT INTO expenses (
    group_id,
    paid_by,
    amount,
    currency,
    category,
    description,
    note,
    expense_date
  )
  VALUES (
    p_group_id,
    p_paid_by,
    p_amount,
    p_currency,
    p_category,
    p_description,
    p_note,
    p_expense_date
  )
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

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO expense_items (expense_id, name, amount, shared_by_user_ids)
    VALUES (
      v_expense_id,
      v_item->>'name',
      (v_item->>'amount')::NUMERIC,
      ARRAY(
        SELECT jsonb_array_elements_text(
          COALESCE(v_item->'shared_by_user_ids', '[]'::JSONB)
        )::UUID
      )
    );
  END LOOP;

  RETURN v_expense_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT p.oid, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'update_expense'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS public.update_expense(%s)', fn.args);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_expense(
  p_expense_id UUID,
  p_paid_by UUID,
  p_amount NUMERIC,
  p_category TEXT,
  p_description TEXT,
  p_note TEXT DEFAULT NULL,
  p_expense_date DATE DEFAULT CURRENT_DATE,
  p_splits JSONB DEFAULT '[]',
  p_items JSONB DEFAULT '[]'
)
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_split JSONB;
  v_item JSONB;
BEGIN
  SELECT group_id INTO v_group_id FROM expenses WHERE id = p_expense_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF NOT is_group_member(v_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  UPDATE expenses
  SET
    paid_by = p_paid_by,
    amount = p_amount,
    category = p_category,
    description = p_description,
    note = p_note,
    expense_date = p_expense_date,
    updated_at = now()
  WHERE id = p_expense_id;

  DELETE FROM expense_splits WHERE expense_id = p_expense_id;
  DELETE FROM expense_items WHERE expense_id = p_expense_id;

  FOR v_split IN SELECT * FROM jsonb_array_elements(p_splits)
  LOOP
    INSERT INTO expense_splits (expense_id, user_id, amount, split_type)
    VALUES (
      p_expense_id,
      (v_split->>'user_id')::UUID,
      (v_split->>'amount')::NUMERIC,
      COALESCE(v_split->>'split_type', 'equal')
    );
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO expense_items (expense_id, name, amount, shared_by_user_ids)
    VALUES (
      p_expense_id,
      v_item->>'name',
      (v_item->>'amount')::NUMERIC,
      ARRAY(
        SELECT jsonb_array_elements_text(
          COALESCE(v_item->'shared_by_user_ids', '[]'::JSONB)
        )::UUID
      )
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
