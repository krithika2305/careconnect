-- ============================================================
-- CareConnect: Medication reminders with pill photos
-- Run once in Supabase SQL Editor (after scheduled_messages exists)
-- ============================================================

ALTER TABLE public.scheduled_messages
  ADD COLUMN IF NOT EXISTS pill_image_url TEXT;

ALTER TABLE public.scheduled_messages
  ADD COLUMN IF NOT EXISTS dosage TEXT;

ALTER TABLE public.scheduled_messages
  ADD COLUMN IF NOT EXISTS instructions TEXT;

SELECT 'Medication pill image columns added to scheduled_messages.' AS result;
