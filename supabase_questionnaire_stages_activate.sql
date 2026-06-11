-- Lets admins manage questionnaire questions and patient stages in the app.
-- Run once in Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('row_security', 'off', true);
  RETURN EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- Questionnaire: caregivers see active only; admins see and manage all
DO $$
DECLARE pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'questionnaire_questions'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.questionnaire_questions', pol.policyname);
  END LOOP;
END $$;

CREATE POLICY "questions_select_active"
  ON public.questionnaire_questions FOR SELECT
  USING (is_active = TRUE OR is_admin());

CREATE POLICY "questions_admin_manage"
  ON public.questionnaire_questions FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Patient stages: admin assign; caregivers/doctors view linked patients
DO $$
DECLARE pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'patient_stages'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.patient_stages', pol.policyname);
  END LOOP;
END $$;

CREATE POLICY "stages_admin_manage"
  ON public.patient_stages FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "stages_caregiver_insert"
  ON public.patient_stages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = patient_stages.patient_id
    )
  );

CREATE POLICY "stages_caregiver_view"
  ON public.patient_stages FOR SELECT
  USING (
    auth.uid() = patient_id
    OR EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = patient_stages.patient_id
    )
    OR is_admin()
  );

SELECT 'Questionnaire + patient stages policies applied.' AS result;
