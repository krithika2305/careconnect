-- ============================================================
-- QUICK FIX: run this if safe_setup failed at mri_predictions
-- Adds patient_id to your old mri table, then run full safe_setup again.
-- ============================================================

ALTER TABLE mri_predictions ADD COLUMN IF NOT EXISTS patient_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE mri_predictions ADD COLUMN IF NOT EXISTS patient_name TEXT;

DROP POLICY IF EXISTS "Doctors can view their own predictions" ON mri_predictions;
DROP POLICY IF EXISTS "Doctors can insert their own predictions" ON mri_predictions;

SELECT 'mri_predictions column fix done. Now run supabase_safe_setup.sql again.' AS result;
