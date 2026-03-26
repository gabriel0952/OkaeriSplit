-- Add payment_info JSONB column to profiles
-- Stores optional bank transfer details for group members to view
-- Structure: { bank_name, branch?, account_number, account_holder }

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS payment_info JSONB;
