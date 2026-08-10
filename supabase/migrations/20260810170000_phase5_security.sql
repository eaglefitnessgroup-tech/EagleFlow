-- Phase 5 Security Remediation: Grants, RPCs & Functions Hardening

-- 1. Revoke unsafe default privileges granted in the remote schema
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON ROUTINES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON ROUTINES FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM authenticated;

-- 2. Revoke implicit execution privileges from PUBLIC and anon for existing functions
REVOKE EXECUTE ON FUNCTION public.current_app_user_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_app_user_id() FROM anon;

REVOKE EXECUTE ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM anon;

REVOKE EXECUTE ON FUNCTION public.get_current_stock(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_stock(uuid) FROM anon;

REVOKE EXECUTE ON FUNCTION public.save_quotation(jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.save_quotation(jsonb) FROM anon;

-- 3. Explicitly grant EXECUTE only to authenticated users (required for RLS policies and Flutter client)
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_stock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_quotation(jsonb) TO authenticated;
