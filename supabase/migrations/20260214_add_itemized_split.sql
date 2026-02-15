-- Support itemized split type in expense_splits
-- The 'itemized' split_type stores the aggregated per-user amounts
-- derived from individual items. The items themselves are stored
-- in a separate table for reference.

-- Update the CHECK constraint to allow 'itemized' as a valid split_type
ALTER TABLE expense_splits
  DROP CONSTRAINT expense_splits_split_type_check;

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

-- Enable RLS
ALTER TABLE expense_items ENABLE ROW LEVEL SECURITY;

-- RLS policy: group members can manage expense items
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
