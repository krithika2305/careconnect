-- Create mri_predictions table
CREATE TABLE mri_predictions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  doctor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_name TEXT,
  image_url TEXT NOT NULL,
  prediction TEXT NOT NULL,
  confidence NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE mri_predictions ENABLE ROW LEVEL SECURITY;

-- Policies
-- Doctors can only select their own prediction history
CREATE POLICY "Doctors can view their own predictions"
  ON mri_predictions
  FOR SELECT
  USING (auth.uid() = doctor_id);

-- Doctors can insert their own predictions
CREATE POLICY "Doctors can insert their own predictions"
  ON mri_predictions
  FOR INSERT
  WITH CHECK (auth.uid() = doctor_id);

-- Create storage bucket for MRI scans
-- Note: This might need to be run via Supabase Dashboard UI if SQL doesn't support bucket creation in your tier.
INSERT INTO storage.buckets (id, name, public) 
VALUES ('mri_scans', 'mri_scans', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for mri_scans bucket
CREATE POLICY "Public read access for MRI scans" 
  ON storage.objects FOR SELECT 
  USING (bucket_id = 'mri_scans');

CREATE POLICY "Authenticated users can upload MRI scans" 
  ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id = 'mri_scans' AND auth.role() = 'authenticated');
