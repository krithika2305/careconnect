-- Doctor-Patient Mapping Schema
-- This table enables caregivers to assign doctors to specific patients

-- Create doctor_patient_mapping table
CREATE TABLE IF NOT EXISTS public.doctor_patient_mapping (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  doctor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  assigned_at TIMESTAMPTZ DEFAULT now(),
  responded_at TIMESTAMPTZ,
  UNIQUE(doctor_id, patient_id)
);

-- Enable Row Level Security
ALTER TABLE public.doctor_patient_mapping ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Caregivers can view mappings where they are the caregiver
DROP POLICY IF EXISTS "Caregivers can view their doctor-patient mappings" ON public.doctor_patient_mapping;
CREATE POLICY "Caregivers can view their doctor-patient mappings"
  ON public.doctor_patient_mapping
  FOR SELECT
  USING (auth.uid() = caregiver_id);

-- Caregivers can insert mappings (assign doctors to their patients)
DROP POLICY IF EXISTS "Caregivers can assign doctors to their patients" ON public.doctor_patient_mapping;
CREATE POLICY "Caregivers can assign doctors to their patients"
  ON public.doctor_patient_mapping
  FOR INSERT
  WITH CHECK (
    auth.uid() = caregiver_id
    AND EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping
      WHERE caregiver_id = auth.uid()
      AND patient_id = doctor_patient_mapping.patient_id
    )
  );

-- Caregivers can update status (cancel pending assignments)
DROP POLICY IF EXISTS "Caregivers can cancel pending assignments" ON public.doctor_patient_mapping;
CREATE POLICY "Caregivers can cancel pending assignments"
  ON public.doctor_patient_mapping
  FOR UPDATE
  USING (
    auth.uid() = caregiver_id
    AND status = 'pending'
  )
  WITH CHECK (
    auth.uid() = caregiver_id
    AND status = 'cancelled'
  );

-- Doctors can view mappings where they are the doctor
DROP POLICY IF EXISTS "Doctors can view their patient assignments" ON public.doctor_patient_mapping;
CREATE POLICY "Doctors can view their patient assignments"
  ON public.doctor_patient_mapping
  FOR SELECT
  USING (auth.uid() = doctor_id);

-- Doctors can update status (accept/reject assignments)
DROP POLICY IF EXISTS "Doctors can respond to assignments" ON public.doctor_patient_mapping;
CREATE POLICY "Doctors can respond to assignments"
  ON public.doctor_patient_mapping
  FOR UPDATE
  USING (
    auth.uid() = doctor_id
    AND status = 'pending'
  )
  WITH CHECK (
    auth.uid() = doctor_id
    AND status IN ('accepted', 'rejected')
    AND responded_at = now()
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_doctor_patient_mapping_doctor_id ON public.doctor_patient_mapping(doctor_id);
CREATE INDEX IF NOT EXISTS idx_doctor_patient_mapping_patient_id ON public.doctor_patient_mapping(patient_id);
CREATE INDEX IF NOT EXISTS idx_doctor_patient_mapping_caregiver_id ON public.doctor_patient_mapping(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_doctor_patient_mapping_status ON public.doctor_patient_mapping(status);

-- Enable Realtime for doctor_patient_mapping table
-- Note: Skip if already enabled to avoid errors
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'doctor_patient_mapping'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.doctor_patient_mapping;
  END IF;
EXCEPTION WHEN others THEN
  -- Ignore if publication add fails (table may already be in publication)
  NULL;
END $$;

-- Function to get assigned patients for a doctor
CREATE OR REPLACE FUNCTION public.get_assigned_patients(p_doctor_id UUID)
RETURNS TABLE (
  id UUID,
  patient_id UUID,
  patient_name TEXT,
  status TEXT,
  assigned_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    dpm.id,
    dpm.patient_id,
    u.name as patient_name,
    dpm.status,
    dpm.assigned_at
  FROM public.doctor_patient_mapping dpm
  JOIN public.users u ON u.id = dpm.patient_id
  WHERE dpm.doctor_id = p_doctor_id
  AND dpm.status = 'accepted'
  ORDER BY dpm.assigned_at DESC;
$$;

-- Function to get assigned doctors for a patient
CREATE OR REPLACE FUNCTION public.get_assigned_doctors(p_patient_id UUID)
RETURNS TABLE (
  id UUID,
  doctor_id UUID,
  doctor_name TEXT,
  doctor_email TEXT,
  status TEXT,
  assigned_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    dpm.id,
    dpm.doctor_id,
    u.name as doctor_name,
    u.email as doctor_email,
    dpm.status,
    dpm.assigned_at
  FROM public.doctor_patient_mapping dpm
  JOIN public.users u ON u.id = dpm.doctor_id
  WHERE dpm.patient_id = p_patient_id
  ORDER BY dpm.assigned_at DESC;
$$;
