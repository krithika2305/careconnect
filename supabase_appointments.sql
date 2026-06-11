-- ============================================================
-- CareConnect: Appointment & visit tracker
-- Run once in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  doctor_name TEXT NOT NULL,
  appointment_type TEXT CHECK (
    appointment_type IS NULL OR appointment_type IN (
      'neurologist', 'primary care', 'therapy', 'other'
    )
  ),
  location TEXT,
  appointment_time TIMESTAMPTZ NOT NULL,
  notes TEXT,
  reminder_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_appointments_patient_time
  ON public.appointments(patient_id, appointment_time);

ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Caregivers create / update / delete linked patient appointments
DROP POLICY IF EXISTS "Caregivers manage appointments" ON public.appointments;
CREATE POLICY "Caregivers manage appointments"
  ON public.appointments FOR ALL
  USING (
    auth.uid() = caregiver_id
    OR EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = appointments.patient_id
    )
  )
  WITH CHECK (
    auth.uid() = caregiver_id
    OR EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = appointments.patient_id
    )
  );

-- Patients view their own upcoming and past visits
DROP POLICY IF EXISTS "Patients view own appointments" ON public.appointments;
CREATE POLICY "Patients view own appointments"
  ON public.appointments FOR SELECT
  USING (auth.uid() = patient_id);

SELECT 'appointments table and RLS applied.' AS result;
