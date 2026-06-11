-- ============================================================
-- CareConnect: Full Database Schema (New Tables)
-- Run this in your Supabase SQL editor
-- ============================================================

-- 1. CAREGIVER <-> PATIENT MAPPING (junction table)
-- ============================================================
CREATE TABLE caregiver_patient_mapping (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
  UNIQUE (caregiver_id, patient_id)
);

ALTER TABLE caregiver_patient_mapping ENABLE ROW LEVEL SECURITY;

-- Caregivers can see their own mappings
CREATE POLICY "Caregivers can view their own mappings"
  ON caregiver_patient_mapping FOR SELECT
  USING (auth.uid() = caregiver_id);

-- Admins can manage all mappings (uses users.role check via helper func)
CREATE POLICY "Admins can manage all mappings"
  ON caregiver_patient_mapping FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- 2. PATIENT PROFILES
-- ============================================================
CREATE TABLE patient_profiles (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  caregiver_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  full_name     TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender        TEXT,
  blood_type    TEXT,
  address       TEXT,
  emergency_contact_name  TEXT,
  emergency_contact_phone TEXT,
  known_allergies         TEXT,
  current_medications     TEXT,
  medical_history         TEXT,
  personal_notes          TEXT,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
  updated_at    TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE patient_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Caregiver can manage their patient's profile"
  ON patient_profiles FOR ALL
  USING (auth.uid() = caregiver_id);

CREATE POLICY "Patient can view own profile"
  ON patient_profiles FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctor can view profiles of their patients"
  ON patient_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor'
    )
  );

CREATE POLICY "Admin full access to patient profiles"
  ON patient_profiles FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- 3. QUESTIONNAIRE QUESTIONS (managed by admin)
-- ============================================================
CREATE TABLE questionnaire_questions (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  question    TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'General',  -- e.g. Memory, Behaviour, Daily Living
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE questionnaire_questions ENABLE ROW LEVEL SECURITY;

-- Everyone authenticated can read active questions
CREATE POLICY "Authenticated users can view active questions"
  ON questionnaire_questions FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = TRUE);

-- Only admins can create/edit/delete
CREATE POLICY "Admins can manage questions"
  ON questionnaire_questions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Seed with default questions
INSERT INTO questionnaire_questions (question, category, sort_order, is_active) VALUES
  ('Does the patient recognise close family members (spouse, children)?', 'Memory', 1, TRUE),
  ('Can the patient recall recent events from the past week?', 'Memory', 2, TRUE),
  ('Does the patient experience confusion about their current location?', 'Orientation', 3, TRUE),
  ('Is the patient able to manage their own daily hygiene independently?', 'Daily Living', 4, TRUE),
  ('Has the patient shown signs of aggression or unusual mood changes?', 'Behaviour', 5, TRUE),
  ('Does the patient have trouble finding words during conversation?', 'Communication', 6, TRUE),
  ('Is the patient experiencing sleep disturbances (wandering at night)?', 'Behaviour', 7, TRUE),
  ('Can the patient follow simple two-step instructions?', 'Cognitive', 8, TRUE),
  ('Has the patient gotten lost in familiar places?', 'Orientation', 9, TRUE),
  ('Does the patient require reminders for medication?', 'Daily Living', 10, TRUE);


-- 4. QUESTIONNAIRE RESPONSES (filled by caregiver every 3 months)
-- ============================================================
CREATE TABLE questionnaire_responses (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  caregiver_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  period_label    TEXT NOT NULL,  -- e.g. "Q2 2025"
  answers         JSONB NOT NULL, -- { "question_id": "Yes"/"No"/"Sometimes" }
  additional_notes TEXT,
  status          TEXT NOT NULL DEFAULT 'SUBMITTED', -- SUBMITTED | REVIEWED
  submitted_at    TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE questionnaire_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Caregiver can manage their own responses"
  ON questionnaire_responses FOR ALL
  USING (auth.uid() = caregiver_id);

CREATE POLICY "Admin can view all responses"
  ON questionnaire_responses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admin can update response status"
  ON questionnaire_responses FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Doctor can view responses for their patients"
  ON questionnaire_responses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor'
    )
  );


-- 5. PATIENT STAGES (admin-assigned dementia staging)
-- ============================================================
CREATE TABLE patient_stages (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  response_id     UUID REFERENCES questionnaire_responses(id) ON DELETE SET NULL,
  assigned_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  stage           TEXT NOT NULL,  -- e.g. "Non Demented", "Very Mild", "Mild", "Moderate", "Severe"
  stage_notes     TEXT,
  assigned_at     TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE patient_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin can manage patient stages"
  ON patient_stages FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Caregiver can view stages for their patients"
  ON patient_stages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = patient_stages.patient_id
    )
  );

CREATE POLICY "Doctor can view all stages"
  ON patient_stages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor'
    )
  );


-- 6. UPDATE RLS ON emergency_alerts (replace open policy with junction-based)
-- ============================================================
-- First, drop the permissive authenticated-only policies
DROP POLICY IF EXISTS "Authenticated users can view alerts" ON emergency_alerts;
DROP POLICY IF EXISTS "Authenticated users can update alerts" ON emergency_alerts;

-- New: Caregivers can only see alerts for THEIR assigned patients
CREATE POLICY "Caregivers can view alerts for their patients"
  ON emergency_alerts FOR SELECT
  USING (
    -- Patient can see own alerts
    auth.uid() = patient_id
    OR
    -- Caregiver mapped to this patient
    EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = emergency_alerts.patient_id
    )
    OR
    -- Doctors and admins can view all
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('doctor', 'admin')
    )
  );

CREATE POLICY "Caregivers can resolve alerts for their patients"
  ON emergency_alerts FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = emergency_alerts.patient_id
    )
    OR
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('doctor', 'admin')
    )
  );


-- 7. ENABLE REALTIME on emergency_alerts
-- ============================================================
-- Run in Supabase Dashboard → Database → Replication, or via SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE emergency_alerts;
