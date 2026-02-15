-- Add attachment_urls column to expenses table
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS attachment_urls TEXT[] DEFAULT '{}';

-- Create receipts storage bucket (public, so getPublicUrl works)
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', true)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for receipts bucket
CREATE POLICY "Authenticated users can upload receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'receipts');

CREATE POLICY "Anyone can read receipts"
ON storage.objects FOR SELECT
USING (bucket_id = 'receipts');

CREATE POLICY "Authenticated users can delete own receipts"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'receipts');
