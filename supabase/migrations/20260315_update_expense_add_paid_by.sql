-- update_expense was missing the p_paid_by parameter.
-- Drop and recreate with the correct signature.

DROP FUNCTION IF EXISTS public.update_expense;

CREATE OR REPLACE FUNCTION public.update_expense(
  p_expense_id   UUID,
  p_paid_by      UUID,
  p_amount       NUMERIC,
  p_category     TEXT,
  p_description  TEXT,
  p_note         TEXT DEFAULT NULL,
  p_expense_date DATE DEFAULT CURRENT_DATE,
  p_splits       JSONB DEFAULT '[]'
)
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_split    JSONB;
BEGIN
  -- Resolve group for membership check
  SELECT group_id INTO v_group_id FROM expenses WHERE id = p_expense_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF NOT is_group_member(v_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  -- Update the expense row
  UPDATE expenses
  SET
    paid_by      = p_paid_by,
    amount       = p_amount,
    category     = p_category,
    description  = p_description,
    note         = p_note,
    expense_date = p_expense_date,
    updated_at   = now()
  WHERE id = p_expense_id;

  -- Replace splits
  DELETE FROM expense_splits WHERE expense_id = p_expense_id;

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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
