-- Allow any authenticated user (caregiver) to read users with role 'doctor'
-- This is essential for the caregiver to see available doctors

DROP POLICY IF EXISTS "Allow authenticated to read doctors" ON users;
CREATE POLICY "Allow authenticated to read doctors"
  ON users FOR SELECT
  USING (auth.role() = 'authenticated' AND role = 'doctor');

-- Allow doctors to read users with role 'patient'
-- This is essential for the doctor to see assigned patients

DROP POLICY IF EXISTS "Doctors can read patients" ON users;
CREATE POLICY "Doctors can read patients"
  ON users FOR SELECT
  USING (auth.role() = 'authenticated' AND role = 'patient');

-- Also ensure doctor_patient_mapping table exists with proper RLS
CREATE TABLE IF NOT EXISTS doctor_patient_mapping (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  doctor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  caregiver_id UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'accepted',
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(doctor_id, patient_id)
);

ALTER TABLE doctor_patient_mapping ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Caregivers can manage mappings" ON doctor_patient_mapping;
CREATE POLICY "Caregivers can manage mappings"
  ON doctor_patient_mapping FOR ALL
  USING (auth.uid() = caregiver_id);

-- Chat messages table (if not exists)
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their own chats" ON chat_messages;
CREATE POLICY "Users can access their own chats"
  ON chat_messages FOR ALL
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
