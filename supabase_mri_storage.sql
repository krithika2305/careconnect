-- Create storage bucket for MRI scans
INSERT INTO storage.buckets (id, name, public) 
VALUES ('mri_scans', 'mri_scans', true)
ON CONFLICT (id) DO NOTHING;
