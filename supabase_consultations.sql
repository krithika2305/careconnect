-- ============================================================
-- CareConnect: ZegoCloud Video Consultation Table & RLS Policies
-- Run once in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.consultations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id TEXT NOT NULL,
  doctor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
  started_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  ended_at TIMESTAMPTZ
);

-- Index for fast status querying by participants
CREATE INDEX IF NOT EXISTS idx_consultations_status 
  ON public.consultations(status);

ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;

-- Policy allowing participant access (Doctors, Patients, and Caregivers)
DROP POLICY IF EXISTS "Users access own consultations" ON public.consultations;
CREATE POLICY "Users access own consultations"
  ON public.consultations FOR ALL
  USING (
    auth.uid() = doctor_id 
    OR auth.uid() = patient_id 
    OR auth.uid() = caregiver_id
  )
  WITH CHECK (
    auth.uid() = doctor_id 
    OR auth.uid() = patient_id 
    OR auth.uid() = caregiver_id
  );

SELECT 'consultations table and RLS applied.' AS result;
