-- ============================================================
-- CareConnect: Mood & energy logger (emoji-based, twice daily)
-- Run once in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.mood_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mood TEXT NOT NULL CHECK (mood IN ('happy', 'neutral', 'sad', 'tired', 'sick')),
  energy_level INTEGER NOT NULL CHECK (energy_level >= 1 AND energy_level <= 5),
  logged_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_mood_logs_patient_day
  ON public.mood_logs(patient_id, logged_at DESC);

ALTER TABLE public.mood_logs ENABLE ROW LEVEL SECURITY;

-- Patients insert and read their own logs
DROP POLICY IF EXISTS "Patients insert own mood logs" ON public.mood_logs;
CREATE POLICY "Patients insert own mood logs"
  ON public.mood_logs FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Patients view own mood logs" ON public.mood_logs;
CREATE POLICY "Patients view own mood logs"
  ON public.mood_logs FOR SELECT
  USING (auth.uid() = patient_id);

-- Caregivers view linked patient mood logs
DROP POLICY IF EXISTS "Caregivers view patient mood logs" ON public.mood_logs;
CREATE POLICY "Caregivers view patient mood logs"
  ON public.mood_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = mood_logs.patient_id
    )
  );

SELECT 'mood_logs table and RLS applied.' AS result;
