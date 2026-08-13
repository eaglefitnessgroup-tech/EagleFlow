-- Phase 1 Security Remediation: Identity, Auth, and app_users Hardening

-- 1. Identity Uniqueness
ALTER TABLE public.app_users ADD CONSTRAINT app_users_supabase_uid_key UNIQUE (supabase_uid);

-- 2. Safe Identity Helper Functions
CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT id FROM public.app_users 
  WHERE supabase_uid = auth.uid()::text AND is_active = true 
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.current_app_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_app_user_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO authenticated;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_users 
    WHERE supabase_uid = auth.uid()::text AND role = 'admin' AND is_active = true
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 3. RLS and Privileges for app_users
REVOKE ALL ON public.app_users FROM anon, authenticated, public;
GRANT SELECT ON public.app_users TO authenticated;

ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to read own profile" ON public.app_users
  FOR SELECT TO authenticated
  USING (
    supabase_uid = auth.uid()::text
  );
