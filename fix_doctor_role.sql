-- ============================================================
-- FIX: Update existing doctor user's role
-- Run this in Supabase SQL Editor
-- ============================================================

-- Replace 'doctor@example.com' with your doctor's actual email
DO $$
DECLARE
  v_user_id UUID;
  v_email TEXT := 'doctoranu123@gmail.com'; -- CHANGE THIS to your doctor's email
BEGIN
  -- Get the user ID from auth.users
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_email;
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. Please update the email in this script.', v_email;
  END IF;
  
  -- Update the role in public.users table
  UPDATE public.users
  SET role = 'doctor'
  WHERE id = v_user_id;
  
  -- Update the auth metadata
  UPDATE auth.users
  SET raw_user_meta_data = jsonb_set(
    COALESCE(raw_user_meta_data, '{}'::jsonb),
    '{role}',
    '"doctor"'::jsonb
  )
  WHERE id = v_user_id;
  
  RAISE NOTICE 'Successfully updated role to doctor for user: %', v_email;
END $$;

-- Verify the change
SELECT 
  au.id,
  au.email,
  au.raw_user_meta_data->>'role' as auth_role,
  u.role as db_role
FROM auth.users au
LEFT JOIN public.users u ON u.id = au.id
WHERE au.email = 'doctoranu123@gmail.com'; -- CHANGE THIS to your doctor's email
