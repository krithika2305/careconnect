-- ============================================================
-- CareConnect: Patient invites & caregiver linking
-- Run in Supabase SQL Editor AFTER supabase_new_schema.sql
-- ============================================================

-- Store email on public users (synced from app on register)
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (lower(email));

-- Pending invites when the patient has not signed up yet
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

CREATE POLICY "Caregivers manage own invites"
  ON care_invites FOR ALL
  USING (auth.uid() = caregiver_id)
  WITH CHECK (auth.uid() = caregiver_id);

CREATE POLICY "Patients view invites for their email"
  ON care_invites FOR SELECT
  USING (
    lower(patient_email) = lower(coalesce(
      (SELECT email FROM users WHERE id = auth.uid()),
      (SELECT email FROM auth.users WHERE id = auth.uid())
    ))
  );

-- Allow caregivers & patients to create mappings
DROP POLICY IF EXISTS "Caregivers can link patients" ON caregiver_patient_mapping;
CREATE POLICY "Caregivers can link patients"
  ON caregiver_patient_mapping FOR INSERT
  WITH CHECK (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS "Patients can accept caregiver link" ON caregiver_patient_mapping;
CREATE POLICY "Patients can accept caregiver link"
  ON caregiver_patient_mapping FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

-- Link existing patient by email, or create a pending invite (RPC)
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
  IF v_caregiver_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_normalized IS NULL OR v_normalized = '' THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  SELECT id INTO v_patient_id
  FROM users
  WHERE lower(email) = v_normalized AND role = 'patient'
  LIMIT 1;

  IF v_patient_id IS NULL THEN
    SELECT au.id INTO v_patient_id
    FROM auth.users au
    INNER JOIN users u ON u.id = au.id AND u.role = 'patient'
    WHERE lower(au.email) = v_normalized
    LIMIT 1;
  END IF;

  IF v_patient_id IS NOT NULL THEN
    INSERT INTO caregiver_patient_mapping (caregiver_id, patient_id)
    VALUES (v_caregiver_id, v_patient_id)
    ON CONFLICT (caregiver_id, patient_id) DO NOTHING;

    RETURN jsonb_build_object(
      'status', 'linked',
      'patient_id', v_patient_id
    );
  END IF;

  INSERT INTO care_invites (caregiver_id, patient_email, patient_name, status)
  VALUES (v_caregiver_id, v_normalized, nullif(trim(p_name), ''), 'pending')
  ON CONFLICT (caregiver_id, patient_email)
  DO UPDATE SET
    patient_name = COALESCE(EXCLUDED.patient_name, care_invites.patient_name),
    status = 'pending',
    created_at = timezone('utc', now())
  RETURNING invite_code INTO v_invite_code;

  RETURN jsonb_build_object(
    'status', 'invited',
    'invite_code', v_invite_code
  );
END;
$$;

GRANT EXECUTE ON FUNCTION link_patient_by_email(TEXT, TEXT) TO authenticated;

-- Called when a patient registers / logs in
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
  IF v_patient_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT coalesce(u.email, au.email) INTO v_email
  FROM auth.users au
  LEFT JOIN users u ON u.id = au.id
  WHERE au.id = v_patient_id;

  IF v_email IS NULL THEN
    RETURN 0;
  END IF;

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

GRANT EXECUTE ON FUNCTION accept_pending_care_invites() TO authenticated;
