-- ============================================================
-- CareConnect: Verification System Schema
-- Run in Supabase SQL Editor AFTER supabase_safe_setup.sql
-- ============================================================

-- ── 1. EXTEND users TABLE WITH VERIFICATION FIELDS ──────────
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS account_status TEXT 
  NOT NULL DEFAULT 'PENDING'
  CHECK (account_status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'DELETED'));

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_status TEXT 
  NOT NULL DEFAULT 'UNVERIFIED'
  CHECK (verification_status IN ('UNVERIFIED', 'PENDING_REVIEW', 'VERIFIED', 'REJECTED'));

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_requested_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_completed_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_rejected_reason TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create indexes for verification queries
CREATE INDEX IF NOT EXISTS idx_users_account_status ON public.users(account_status);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status);
CREATE INDEX IF NOT EXISTS idx_users_role_verification ON public.users(role, verification_status);

-- ── 2. USER VERIFICATION REQUESTS TABLE ──────────────────────
CREATE TABLE IF NOT EXISTS user_verification_requests (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('doctor', 'caregiver')),
  verification_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'approved', 'rejected')),
  submitted_documents JSONB DEFAULT '{}',
  submitted_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  rejection_reason TEXT,
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE user_verification_requests ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_verif_req_user_id ON user_verification_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_verif_req_status ON user_verification_requests(status);
CREATE INDEX IF NOT EXISTS idx_verif_req_role ON user_verification_requests(role);

DROP POLICY IF EXISTS "Users can view own verification requests" ON user_verification_requests;
CREATE POLICY "Users can view own verification requests"
  ON user_verification_requests FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all verification requests" ON user_verification_requests;
CREATE POLICY "Admins can view all verification requests"
  ON user_verification_requests FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Users can insert own verification requests" ON user_verification_requests;
CREATE POLICY "Users can insert own verification requests"
  ON user_verification_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can update verification requests" ON user_verification_requests;
CREATE POLICY "Admins can update verification requests"
  ON user_verification_requests FOR UPDATE
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ── 3. DOCTOR CREDENTIALS TABLE ──────────────────────────────
CREATE TABLE IF NOT EXISTS doctor_credentials (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  license_number TEXT,
  license_state TEXT,
  medical_school TEXT,
  years_experience INTEGER,
  specialization TEXT,
  board_certified BOOLEAN DEFAULT FALSE,
  license_document_path TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE doctor_credentials ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_doctor_credentials_user_id ON doctor_credentials(user_id);

DROP POLICY IF EXISTS "Users can view own credentials" ON doctor_credentials;
CREATE POLICY "Users can view own credentials"
  ON doctor_credentials FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all credentials" ON doctor_credentials;
CREATE POLICY "Admins can view all credentials"
  ON doctor_credentials FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Users can update own credentials" ON doctor_credentials;
CREATE POLICY "Users can update own credentials"
  ON doctor_credentials FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert credentials" ON doctor_credentials;
CREATE POLICY "Users can insert credentials"
  ON doctor_credentials FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── 4. CAREGIVER VERIFICATION TABLE ──────────────────────────
CREATE TABLE IF NOT EXISTS caregiver_verification (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  background_check_status TEXT DEFAULT 'pending'
    CHECK (background_check_status IN ('pending', 'clear', 'failed')),
  training_certificate BOOLEAN DEFAULT FALSE,
  professional_background TEXT,
  certificate_document_path TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE caregiver_verification ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_caregiver_verification_user_id ON caregiver_verification(user_id);

DROP POLICY IF EXISTS "Users can view own caregiver verification" ON caregiver_verification;
CREATE POLICY "Users can view own caregiver verification"
  ON caregiver_verification FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all caregiver verifications" ON caregiver_verification;
CREATE POLICY "Admins can view all caregiver verifications"
  ON caregiver_verification FOR SELECT
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Users can update own caregiver verification" ON caregiver_verification;
CREATE POLICY "Users can update own caregiver verification"
  ON caregiver_verification FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert caregiver verification" ON caregiver_verification;
CREATE POLICY "Users can insert caregiver verification"
  ON caregiver_verification FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── 5. UPDATE DOCTOR_PATIENT_MAPPING WITH VERIFICATION ───────
ALTER TABLE public.doctor_patient_mapping ADD COLUMN IF NOT EXISTS 
  verification_required BOOLEAN DEFAULT TRUE;

ALTER TABLE public.doctor_patient_mapping ADD COLUMN IF NOT EXISTS 
  verification_status TEXT DEFAULT 'pending_doctor_verify'
  CHECK (verification_status IN ('pending_doctor_verify', 'doctor_verified', 'active'));

-- ── 6. UPDATE CARE_INVITES WITH VERIFICATION STATUS ──────────
ALTER TABLE care_invites ADD COLUMN IF NOT EXISTS 
  caregiver_verification_status TEXT DEFAULT 'unverified';

ALTER TABLE care_invites ADD COLUMN IF NOT EXISTS 
  caregiver_verified_at TIMESTAMPTZ;

-- ── 7. RLS POLICIES TO PREVENT UNVERIFIED ACCESS ─────────────

-- Prevent unverified doctors from viewing doctor_patient_mapping
DROP POLICY IF EXISTS "Unverified doctors cannot view assignments" ON doctor_patient_mapping;
CREATE POLICY "Unverified doctors cannot view assignments"
  ON doctor_patient_mapping FOR SELECT
  USING (
    (auth.uid() = doctor_id AND 
     EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND verification_status = 'VERIFIED')) OR
    auth.uid() = caregiver_id OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- Enable Realtime for new tables
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'user_verification_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_verification_requests;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'doctor_credentials'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.doctor_credentials;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'caregiver_verification'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.caregiver_verification;
  END IF;
EXCEPTION WHEN others THEN
  NULL;
END $$;

-- ── 8. BACKFILL: Set existing verified doctors to VERIFIED ────
-- (Assumes existing doctors should be marked verified; adjust as needed)
UPDATE public.users 
SET 
  account_status = 'ACTIVE',
  verification_status = 'VERIFIED',
  verification_completed_at = created_at
WHERE role = 'doctor' AND account_status = 'PENDING';

-- Set all other accounts to ACTIVE by default (can be changed per role)
UPDATE public.users 
SET account_status = 'ACTIVE'
WHERE account_status = 'PENDING' AND role IN ('patient', 'admin');

-- Caregivers start with PENDING verification
UPDATE public.users 
SET 
  account_status = 'PENDING',
  verification_status = 'UNVERIFIED'
WHERE role = 'caregiver' AND account_status = 'ACTIVE';
