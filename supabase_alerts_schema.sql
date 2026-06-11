-- Create emergency_alerts table
CREATE TABLE emergency_alerts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_name TEXT,
  alert_type TEXT NOT NULL,
  status TEXT DEFAULT 'ACTIVE',
  latitude NUMERIC,
  longitude NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  resolved_at TIMESTAMP WITH TIME ZONE
);

-- Enable Row Level Security (RLS)
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;

-- Policies for Patient (Insert & View)
CREATE POLICY "Patients can insert their own alerts"
  ON emergency_alerts
  FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can view their own alerts"
  ON emergency_alerts
  FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Patients can update their own alerts"
  ON emergency_alerts
  FOR UPDATE
  USING (auth.uid() = patient_id);

-- Policies for Caregiver/Doctor (For this demo, we can allow authenticated users to select/update active alerts)
-- In a strict production system, there would be a junction table linking specific caregivers to patients.
CREATE POLICY "Authenticated users can view alerts"
  ON emergency_alerts
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update alerts"
  ON emergency_alerts
  FOR UPDATE
  USING (auth.role() = 'authenticated');
