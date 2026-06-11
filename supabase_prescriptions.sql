-- ============================================================
-- CareConnect: Prescriptions + doctor clinical permissions
-- Run once in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.prescriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  medication_name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT,
  start_date DATE,
  end_date DATE,
  instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_prescriptions_patient
  ON public.prescriptions(patient_id, created_at DESC);

ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Doctors manage prescriptions" ON public.prescriptions;
CREATE POLICY "Doctors manage prescriptions"
  ON public.prescriptions FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
  );

DROP POLICY IF EXISTS "Patients view own prescriptions" ON public.prescriptions;
CREATE POLICY "Patients view own prescriptions"
  ON public.prescriptions FOR SELECT
  USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Caregivers view patient prescriptions" ON public.prescriptions;
CREATE POLICY "Caregivers view patient prescriptions"
  ON public.prescriptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = prescriptions.patient_id
    )
  );

-- Doctors: list patients (avoids recursive users RLS)
CREATE OR REPLACE FUNCTION public.get_patients_for_doctor()
RETURNS TABLE (id UUID, name TEXT, email TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id, u.name, u.email
  FROM public.users u
  WHERE u.role = 'patient'
    AND EXISTS (
      SELECT 1 FROM public.users d
      WHERE d.id = auth.uid() AND d.role IN ('doctor', 'admin')
    )
  ORDER BY u.name;
$$;

GRANT EXECUTE ON FUNCTION public.get_patients_for_doctor() TO authenticated;

-- Doctors: assign dementia stages
DROP POLICY IF EXISTS "stages_doctor_insert" ON public.patient_stages;
CREATE POLICY "stages_doctor_insert"
  ON public.patient_stages FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
  );

DROP POLICY IF EXISTS "stages_doctor_view" ON public.patient_stages;
CREATE POLICY "stages_doctor_view"
  ON public.patient_stages FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
  );

-- Doctors: create medication reminders for linked patients
DROP POLICY IF EXISTS "Doctors insert patient medication reminders" ON public.scheduled_messages;
CREATE POLICY "Doctors insert patient medication reminders"
  ON public.scheduled_messages FOR INSERT
  WITH CHECK (
    type = 'medication'
    AND EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
    AND EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping m
      WHERE m.patient_id = scheduled_messages.patient_id
        AND m.caregiver_id = scheduled_messages.caregiver_id
    )
  );

SELECT 'prescriptions table, doctor RPC, and clinical policies applied.' AS result;
