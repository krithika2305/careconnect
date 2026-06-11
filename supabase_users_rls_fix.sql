-- ============================================================
-- CareConnect: FIX users table RLS (run entire file in Supabase SQL Editor)
-- Fixes: infinite recursion detected in policy for relation "users"
-- ============================================================

-- 1. Ensure table exists
CREATE TABLE IF NOT EXISTS public.users (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL DEFAULT '',
  role       TEXT NOT NULL DEFAULT 'caregiver',
  email      TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Backfill missing profiles from auth.users
INSERT INTO public.users (id, name, role, email)
SELECT
  au.id,
  COALESCE(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1), 'User'),
  COALESCE(au.raw_user_meta_data->>'role', 'caregiver'),
  au.email
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = au.id);

-- 3. DROP EVERY policy on users (removes broken recursive ones)
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.users', pol.policyname);
  END LOOP;
END $$;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 4. ONLY simple policies — never query users inside users policies
CREATE POLICY "users_insert_own"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- 5. Save profile (bypasses RLS)
CREATE OR REPLACE FUNCTION public.ensure_user_profile(
  p_name  TEXT,
  p_role  TEXT,
  p_email TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM set_config('row_security', 'off', true);

  INSERT INTO public.users (id, name, role, email)
  VALUES (auth.uid(), p_name, p_role, lower(trim(p_email)))
  ON CONFLICT (id) DO UPDATE SET
    name  = EXCLUDED.name,
    role  = EXCLUDED.role,
    email = EXCLUDED.email;
END;
$$;

-- 6. Read own profile (bypasses RLS — app uses this instead of direct SELECT)
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM set_config('row_security', 'off', true);

  SELECT json_build_object(
    'id',    u.id,
    'name',  u.name,
    'role',  u.role,
    'email', u.email
  )
  INTO result
  FROM public.users u
  WHERE u.id = auth.uid();

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_user_profile(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

-- 7. Auto-create profile on new auth signup
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('row_security', 'off', true);

  INSERT INTO public.users (id, name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'caregiver'),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- 8. Drop old helper functions that could still cause recursion in other policies
DROP FUNCTION IF EXISTS public.is_admin_or_doctor();
DROP FUNCTION IF EXISTS public.get_my_role();

SELECT 'SUCCESS: users RLS fixed. Re-run app and tap Save and continue.' AS result;
