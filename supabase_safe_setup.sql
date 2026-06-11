-- ============================================================
-- CareConnect: SAFE SETUP (run on existing database)
-- Safe to run multiple times — skips objects that already exist.
-- Use this if you get "already exists" or "does not exist" errors.
-- ============================================================

-- ── USERS: add email column (for invite linking) ─────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (lower(email));

-- ── 1. CAREGIVER <-> PATIENT MAPPING ─────────────────────────
CREATE TABLE IF NOT EXISTS caregiver_patient_mapping (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT timezone('utc', now()),
  UNIQUE (caregiver_id, patient_id)
);
ALTER TABLE caregiver_patient_mapping ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregivers can view their own mappings" ON caregiver_patient_mapping;
CREATE POLICY "Caregivers can view their own mappings"
  ON caregiver_patient_mapping FOR SELECT
  USING (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Admins can manage all mappings" ON caregiver_patient_mapping;
CREATE POLICY "Admins can manage all mappings"
  ON caregiver_patient_mapping FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Caregivers can link patients" ON caregiver_patient_mapping;
CREATE POLICY "Caregivers can link patients"
  ON caregiver_patient_mapping FOR INSERT
  WITH CHECK (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Patients can accept caregiver link" ON caregiver_patient_mapping;
CREATE POLICY "Patients can accept caregiver link"
  ON caregiver_patient_mapping FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

-- ── 2. PATIENT PROFILES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS patient_profiles (
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
  created_at    TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at    TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE patient_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregiver can manage their patient's profile" ON patient_profiles;
CREATE POLICY "Caregiver can manage their patient's profile"
  ON patient_profiles FOR ALL USING (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Patient can view own profile" ON patient_profiles;
CREATE POLICY "Patient can view own profile"
  ON patient_profiles FOR SELECT USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Doctor can view profiles of their patients" ON patient_profiles;
CREATE POLICY "Doctor can view profiles of their patients"
  ON patient_profiles FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor'));

DROP POLICY IF EXISTS "Admin full access to patient profiles" ON patient_profiles;
CREATE POLICY "Admin full access to patient profiles"
  ON patient_profiles FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ── 3. QUESTIONNAIRE QUESTIONS ───────────────────────────────
CREATE TABLE IF NOT EXISTS questionnaire_questions (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  question    TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'General',
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at  TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE questionnaire_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view active questions" ON questionnaire_questions;
CREATE POLICY "Authenticated users can view active questions"
  ON questionnaire_questions FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = TRUE);

DROP POLICY IF EXISTS "Admins can manage questions" ON questionnaire_questions;
CREATE POLICY "Admins can manage questions"
  ON questionnaire_questions FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

INSERT INTO questionnaire_questions (question, category, sort_order, is_active)
SELECT q, c, s, TRUE FROM (VALUES
  ('Does the patient recognise close family members (spouse, children)?', 'Memory', 1),
  ('Can the patient recall recent events from the past week?', 'Memory', 2),
  ('Does the patient experience confusion about their current location?', 'Orientation', 3),
  ('Is the patient able to manage their own daily hygiene independently?', 'Daily Living', 4),
  ('Has the patient shown signs of aggression or unusual mood changes?', 'Behaviour', 5),
  ('Does the patient have trouble finding words during conversation?', 'Communication', 6),
  ('Is the patient experiencing sleep disturbances (wandering at night)?', 'Behaviour', 7),
  ('Can the patient follow simple two-step instructions?', 'Cognitive', 8),
  ('Has the patient gotten lost in familiar places?', 'Orientation', 9),
  ('Does the patient require reminders for medication?', 'Daily Living', 10)
) AS v(q, c, s)
WHERE NOT EXISTS (SELECT 1 FROM questionnaire_questions LIMIT 1);

-- ── 4. QUESTIONNAIRE RESPONSES ───────────────────────────────
CREATE TABLE IF NOT EXISTS questionnaire_responses (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  caregiver_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  period_label    TEXT NOT NULL,
  answers         JSONB NOT NULL,
  additional_notes TEXT,
  status          TEXT NOT NULL DEFAULT 'SUBMITTED',
  submitted_at    TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE questionnaire_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregiver can manage their own responses" ON questionnaire_responses;
CREATE POLICY "Caregiver can manage their own responses"
  ON questionnaire_responses FOR ALL USING (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Admin can view all responses" ON questionnaire_responses;
CREATE POLICY "Admin can view all responses"
  ON questionnaire_responses FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Admin can update response status" ON questionnaire_responses;
CREATE POLICY "Admin can update response status"
  ON questionnaire_responses FOR UPDATE
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Doctor can view responses for their patients" ON questionnaire_responses;
CREATE POLICY "Doctor can view responses for their patients"
  ON questionnaire_responses FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor'));

-- ── 5. PATIENT STAGES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patient_stages (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  response_id     UUID REFERENCES questionnaire_responses(id) ON DELETE SET NULL,
  assigned_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  stage           TEXT NOT NULL,
  stage_notes     TEXT,
  assigned_at     TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE patient_stages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin can manage patient stages" ON patient_stages;
CREATE POLICY "Admin can manage patient stages"
  ON patient_stages FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Caregiver can view stages for their patients" ON patient_stages;
CREATE POLICY "Caregiver can view stages for their patients"
  ON patient_stages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM caregiver_patient_mapping
    WHERE caregiver_id = auth.uid() AND patient_id = patient_stages.patient_id
  ));

DROP POLICY IF EXISTS "Doctor can view all stages" ON patient_stages;
CREATE POLICY "Doctor can view all stages"
  ON patient_stages FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor'));

-- ── 6. EMERGENCY ALERTS RLS (table must already exist) ───────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'emergency_alerts') THEN
    DROP POLICY IF EXISTS "Authenticated users can view alerts" ON emergency_alerts;
    DROP POLICY IF EXISTS "Authenticated users can update alerts" ON emergency_alerts;
    DROP POLICY IF EXISTS "Caregivers can view alerts for their patients" ON emergency_alerts;
    DROP POLICY IF EXISTS "Caregivers can resolve alerts for their patients" ON emergency_alerts;

    CREATE POLICY "Caregivers can view alerts for their patients"
      ON emergency_alerts FOR SELECT
      USING (
        auth.uid() = patient_id
        OR EXISTS (
          SELECT 1 FROM caregiver_patient_mapping
          WHERE caregiver_id = auth.uid() AND patient_id = emergency_alerts.patient_id
        )
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('doctor', 'admin'))
      );

    CREATE POLICY "Caregivers can resolve alerts for their patients"
      ON emergency_alerts FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM caregiver_patient_mapping
          WHERE caregiver_id = auth.uid() AND patient_id = emergency_alerts.patient_id
        )
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('doctor', 'admin'))
      );
  END IF;
END $$;

-- Realtime (ignore if already added)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE emergency_alerts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 7. COGNITIVE TESTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS cognitive_tests (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ai_status TEXT,
  missed_game INTEGER DEFAULT 0,
  duration INTEGER,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE cognitive_tests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own or patient cognitive_tests" ON cognitive_tests;
CREATE POLICY "Users can view own or patient cognitive_tests"
  ON cognitive_tests FOR SELECT
  USING (
    auth.uid() = patient_id OR
    EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND caregiver_patient_mapping.patient_id = cognitive_tests.patient_id
    ) OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'doctor'))
  );

DROP POLICY IF EXISTS "Users can insert cognitive_tests" ON cognitive_tests;
CREATE POLICY "Users can insert cognitive_tests"
  ON cognitive_tests FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ── 8. SCHEDULED MESSAGES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS scheduled_messages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  type TEXT NOT NULL,
  scheduled_time TIME NOT NULL,
  repeat_pattern TEXT,
  repeat_days JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE scheduled_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregivers manage their scheduled messages" ON scheduled_messages;
CREATE POLICY "Caregivers manage their scheduled messages"
  ON scheduled_messages FOR ALL USING (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Patients view their own messages" ON scheduled_messages;
CREATE POLICY "Patients view their own messages"
  ON scheduled_messages FOR SELECT USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Admins/Doctors view all messages" ON scheduled_messages;
CREATE POLICY "Admins/Doctors view all messages"
  ON scheduled_messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'doctor')));

-- ── 9. MESSAGE LOGS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS message_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  message_id UUID REFERENCES scheduled_messages(id) ON DELETE SET NULL,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  delivered_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  status TEXT
);
ALTER TABLE message_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view relevant message logs" ON message_logs;
CREATE POLICY "Users can view relevant message logs"
  ON message_logs FOR SELECT
  USING (
    auth.uid() = patient_id OR
    EXISTS (SELECT 1 FROM caregiver_patient_mapping WHERE caregiver_id = auth.uid() AND patient_id = message_logs.patient_id) OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'doctor'))
  );

DROP POLICY IF EXISTS "System can insert logs" ON message_logs;
CREATE POLICY "System can insert logs"
  ON message_logs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ── 10. MEMORY PHOTOS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS memory_photos (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  uploader_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT NOT NULL,
  person_name TEXT,
  relation TEXT,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE memory_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregivers manage their uploaded photos" ON memory_photos;
CREATE POLICY "Caregivers manage their uploaded photos"
  ON memory_photos FOR ALL USING (auth.uid() = uploader_id);

DROP POLICY IF EXISTS "Patients view their own photos" ON memory_photos;
CREATE POLICY "Patients view their own photos"
  ON memory_photos FOR SELECT USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Admins/Doctors view all photos" ON memory_photos;
CREATE POLICY "Admins/Doctors view all photos"
  ON memory_photos FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'doctor')));

-- ── 11. MRI PREDICTIONS (migrate old table if needed) ─────────
CREATE TABLE IF NOT EXISTS mri_predictions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  doctor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  patient_name TEXT,
  image_url TEXT NOT NULL,
  prediction TEXT NOT NULL,
  confidence NUMERIC NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- Upgrade older installs that only had patient_name (from supabase_mri_schema.sql)
ALTER TABLE mri_predictions ADD COLUMN IF NOT EXISTS patient_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE mri_predictions ADD COLUMN IF NOT EXISTS patient_name TEXT;

ALTER TABLE mri_predictions ENABLE ROW LEVEL SECURITY;

-- Remove legacy policy names from the old MRI script
DROP POLICY IF EXISTS "Doctors can view their own predictions" ON mri_predictions;
DROP POLICY IF EXISTS "Doctors can insert their own predictions" ON mri_predictions;
DROP POLICY IF EXISTS "Doctors manage their MRI predictions" ON mri_predictions;
CREATE POLICY "Doctors manage their MRI predictions"
  ON mri_predictions FOR ALL USING (auth.uid() = doctor_id);

DROP POLICY IF EXISTS "Caregivers view patient predictions" ON mri_predictions;
CREATE POLICY "Caregivers view patient predictions"
  ON mri_predictions FOR SELECT
  USING (
    patient_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM caregiver_patient_mapping
      WHERE caregiver_id = auth.uid() AND patient_id = mri_predictions.patient_id
    )
  );

DROP POLICY IF EXISTS "Admins view all predictions" ON mri_predictions;
CREATE POLICY "Admins view all predictions"
  ON mri_predictions FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ── 12. GEOFENCES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS geofences (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  caregiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  latitude NUMERIC NOT NULL,
  longitude NUMERIC NOT NULL,
  radius_meters NUMERIC NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE geofences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregivers manage their patient geofences" ON geofences;
CREATE POLICY "Caregivers manage their patient geofences"
  ON geofences FOR ALL USING (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Patients view their own geofence" ON geofences;
CREATE POLICY "Patients view their own geofence"
  ON geofences FOR SELECT USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Admins view all geofences" ON geofences;
CREATE POLICY "Admins view all geofences"
  ON geofences FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ── 13. CARE INVITES ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS care_invites (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  caregiver_id  UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_email TEXT NOT NULL,
  patient_name  TEXT,
  invite_code   TEXT UNIQUE NOT NULL DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'cancelled')),
  patient_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT timezone('utc', now()),
  accepted_at   TIMESTAMPTZ,
  UNIQUE (caregiver_id, patient_email)
);
ALTER TABLE care_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregivers manage own invites" ON care_invites;
CREATE POLICY "Caregivers manage own invites"
  ON care_invites FOR ALL
  USING (auth.uid() = caregiver_id)
  WITH CHECK (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Patients view invites for their email" ON care_invites;
CREATE POLICY "Patients view invites for their email"
  ON care_invites FOR SELECT
  USING (
    lower(patient_email) = lower(coalesce(
      (SELECT email FROM users WHERE id = auth.uid()),
      (SELECT email FROM auth.users WHERE id = auth.uid())
    ))
  );

-- ── 14. INVITE RPC FUNCTIONS ─────────────────────────────────
CREATE OR REPLACE FUNCTION link_patient_by_email(p_email TEXT, p_name TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caregiver_id UUID := auth.uid();
  v_patient_id   UUID;
  v_invite_code  TEXT;
  v_normalized   TEXT := lower(trim(p_email));
BEGIN
  IF v_caregiver_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF v_normalized IS NULL OR v_normalized = '' THEN RAISE EXCEPTION 'Email is required'; END IF;

  SELECT id INTO v_patient_id FROM users
  WHERE lower(email) = v_normalized AND role = 'patient' LIMIT 1;

  IF v_patient_id IS NULL THEN
    SELECT au.id INTO v_patient_id FROM auth.users au
    INNER JOIN users u ON u.id = au.id AND u.role = 'patient'
    WHERE lower(au.email) = v_normalized LIMIT 1;
  END IF;

  IF v_patient_id IS NOT NULL THEN
    INSERT INTO caregiver_patient_mapping (caregiver_id, patient_id)
    VALUES (v_caregiver_id, v_patient_id)
    ON CONFLICT (caregiver_id, patient_id) DO NOTHING;
    RETURN jsonb_build_object('status', 'linked', 'patient_id', v_patient_id);
  END IF;

  INSERT INTO care_invites (caregiver_id, patient_email, patient_name, status)
  VALUES (v_caregiver_id, v_normalized, nullif(trim(p_name), ''), 'pending')
  ON CONFLICT (caregiver_id, patient_email)
  DO UPDATE SET
    patient_name = COALESCE(EXCLUDED.patient_name, care_invites.patient_name),
    status = 'pending',
    created_at = timezone('utc', now())
  RETURNING invite_code INTO v_invite_code;

  RETURN jsonb_build_object('status', 'invited', 'invite_code', v_invite_code);
END;
$$;

CREATE OR REPLACE FUNCTION accept_pending_care_invites()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_patient_id UUID := auth.uid();
  v_email      TEXT;
  v_count      INTEGER := 0;
  r            RECORD;
BEGIN
  IF v_patient_id IS NULL THEN RETURN 0; END IF;

  SELECT coalesce(u.email, au.email) INTO v_email
  FROM auth.users au LEFT JOIN users u ON u.id = au.id
  WHERE au.id = v_patient_id;

  IF v_email IS NULL THEN RETURN 0; END IF;

  FOR r IN
    SELECT id, caregiver_id FROM care_invites
    WHERE lower(patient_email) = lower(v_email) AND status = 'pending'
  LOOP
    INSERT INTO caregiver_patient_mapping (caregiver_id, patient_id)
    VALUES (r.caregiver_id, v_patient_id)
    ON CONFLICT (caregiver_id, patient_id) DO NOTHING;

    UPDATE care_invites
    SET status = 'accepted', patient_id = v_patient_id, accepted_at = timezone('utc', now())
    WHERE id = r.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION link_patient_by_email(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION accept_pending_care_invites() TO authenticated;

-- ── Done ─────────────────────────────────────────────────────
SELECT 'CareConnect safe setup completed successfully.' AS result;
