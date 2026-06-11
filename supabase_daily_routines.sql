-- ============================================================
-- CareConnect: Daily routine checklist
-- Run once in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.daily_routines (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  task_name TEXT NOT NULL,
  time_of_day TEXT NOT NULL CHECK (time_of_day IN ('morning', 'afternoon', 'evening')),
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.routine_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  routine_id UUID NOT NULL REFERENCES public.daily_routines(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  status TEXT DEFAULT 'completed'
);

CREATE INDEX IF NOT EXISTS idx_daily_routines_patient ON public.daily_routines(patient_id);
CREATE INDEX IF NOT EXISTS idx_routine_logs_patient_day ON public.routine_logs(patient_id, completed_at);

ALTER TABLE public.daily_routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_logs ENABLE ROW LEVEL SECURITY;

-- ── daily_routines policies ──────────────────────────────────
DROP POLICY IF EXISTS "Caregivers manage daily routines" ON public.daily_routines;
CREATE POLICY "Caregivers manage daily routines"
  ON public.daily_routines FOR ALL
  USING (
    auth.uid() = caregiver_id
    OR EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = daily_routines.patient_id
    )
  )
  WITH CHECK (
    auth.uid() = caregiver_id
    OR EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = daily_routines.patient_id
    )
  );

DROP POLICY IF EXISTS "Patients view own daily routines" ON public.daily_routines;
CREATE POLICY "Patients view own daily routines"
  ON public.daily_routines FOR SELECT
  USING (auth.uid() = patient_id AND is_active = TRUE);

-- ── routine_logs policies ────────────────────────────────────
DROP POLICY IF EXISTS "Patients log own routine completion" ON public.routine_logs;
CREATE POLICY "Patients log own routine completion"
  ON public.routine_logs FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Patients view own routine logs" ON public.routine_logs;
CREATE POLICY "Patients view own routine logs"
  ON public.routine_logs FOR SELECT
  USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Caregivers view patient routine logs" ON public.routine_logs;
CREATE POLICY "Caregivers view patient routine logs"
  ON public.routine_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = routine_logs.patient_id
    )
  );

SELECT 'Daily routines tables and RLS applied.' AS result;
