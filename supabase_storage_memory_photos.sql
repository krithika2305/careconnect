-- ============================================================
-- CareConnect: Memory Photos storage bucket
-- Fixes: StorageException — Bucket not found (careconnect_media)
-- Run once in Supabase → SQL Editor
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('careconnect_media', 'careconnect_media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public read careconnect_media" ON storage.objects;
CREATE POLICY "Public read careconnect_media"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'careconnect_media');

DROP POLICY IF EXISTS "Authenticated upload careconnect_media" ON storage.objects;
CREATE POLICY "Authenticated upload careconnect_media"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'careconnect_media'
    AND auth.uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "Users update own careconnect_media" ON storage.objects;
CREATE POLICY "Users update own careconnect_media"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'careconnect_media' AND auth.uid() = owner);

DROP POLICY IF EXISTS "Users delete own careconnect_media" ON storage.objects;
CREATE POLICY "Users delete own careconnect_media"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'careconnect_media' AND auth.uid() = owner);

SELECT 'SUCCESS: careconnect_media bucket ready for memory photo uploads.' AS result;
