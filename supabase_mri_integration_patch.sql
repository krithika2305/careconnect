-- 1. Add metadata column to chat_messages if it does not exist
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS metadata TEXT;

-- 2. Create the mri_scans storage bucket (if not already existing)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('mri_scans', 'mri_scans', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Add RLS policies for storage bucket
DROP POLICY IF EXISTS "Public access to mri_scans" ON storage.objects;
CREATE POLICY "Public access to mri_scans"
ON storage.objects FOR SELECT
USING (bucket_id = 'mri_scans');

DROP POLICY IF EXISTS "Authenticated upload to mri_scans" ON storage.objects;
CREATE POLICY "Authenticated upload to mri_scans"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'mri_scans' AND auth.role() = 'authenticated');
