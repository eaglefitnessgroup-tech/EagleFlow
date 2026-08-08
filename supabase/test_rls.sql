-- First, clear and setup app_users
TRUNCATE public.app_users CASCADE;
INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid) VALUES
('SALES-001', 'Sales A', 'salesA', 'salesA@example.com', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111'),
('SALES-002', 'Sales B', 'salesB', 'salesB@example.com', '', 'salesperson', true, now(), '22222222-2222-2222-2222-222222222222'),
('ADMIN-001', 'Admin', 'admin', 'admin@example.com', '', 'admin', true, now(), '33333333-3333-3333-3333-333333333333'),
('INACTIVE-001', 'Inactive', 'inactive', 'inactive@example.com', '', 'salesperson', false, now(), '44444444-4444-4444-4444-444444444444');

-- Test unauthenticated access (anon)
SET ROLE anon;
-- Test SELECT
DO $$
BEGIN
    PERFORM * FROM public.app_users;
    RAISE NOTICE 'ANON SELECT ALLOWED (UNEXPECTED)';
EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN
    RAISE NOTICE 'ANON SELECT DENIED (EXPECTED)';
END $$;
-- Test INSERT
DO $$ BEGIN INSERT INTO public.app_users(id, supabase_uid, username) VALUES ('TEST', 'test', 'test'); RAISE NOTICE 'ANON INSERT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON INSERT DENIED (EXPECTED)'; END $$;
-- Test UPDATE
DO $$ BEGIN UPDATE public.app_users SET name = 'TEST'; RAISE NOTICE 'ANON UPDATE ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON UPDATE DENIED (EXPECTED)'; END $$;
-- Test DELETE
DO $$ BEGIN DELETE FROM public.app_users; RAISE NOTICE 'ANON DELETE ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON DELETE DENIED (EXPECTED)'; END $$;

-- Test Functions as anon
DO $$ BEGIN PERFORM public.current_app_user_id(); RAISE NOTICE 'ANON current_app_user_id ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON current_app_user_id DENIED (EXPECTED)'; END $$;
DO $$ BEGIN PERFORM public.is_admin(); RAISE NOTICE 'ANON is_admin ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON is_admin DENIED (EXPECTED)'; END $$;

-- Test authenticated own-profile RLS (User A)
SET ROLE authenticated;
-- Mock JWT for User A
SET request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}';

-- Test SELECT (User A)
SELECT id as user_a_visible_id FROM public.app_users;

-- Test INSERT/UPDATE/DELETE (User A)
DO $$ BEGIN UPDATE public.app_users SET name = 'Hacked'; RAISE NOTICE 'USER A UPDATE ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'USER A UPDATE DENIED (EXPECTED)'; END $$;
DO $$ BEGIN DELETE FROM public.app_users; RAISE NOTICE 'USER A DELETE ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'USER A DELETE DENIED (EXPECTED)'; END $$;
DO $$ BEGIN INSERT INTO public.app_users(id, supabase_uid, username) VALUES ('TEST', 'test', 'test'); RAISE NOTICE 'USER A INSERT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'USER A INSERT DENIED (EXPECTED)'; END $$;

-- Test Admin Behavior
SET request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333"}';
SELECT id as admin_visible_id FROM public.app_users;

-- Test helper functions (Admin)
SELECT public.is_admin() as is_admin_result;
SELECT public.current_app_user_id() as current_id_result;

-- Test User A again
SET request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}';
SELECT public.is_admin() as is_admin_result_sales;
SELECT public.current_app_user_id() as current_id_result_sales;

-- Test missing profile fails closed
SET request.jwt.claims TO '{"sub": "99999999-9999-9999-9999-999999999999"}';
SELECT public.is_admin() as is_admin_missing;
SELECT public.current_app_user_id() as current_id_missing;

-- Test inactive profile fails closed
SET request.jwt.claims TO '{"sub": "44444444-4444-4444-4444-444444444444"}';
SELECT public.is_admin() as is_admin_inactive;
SELECT public.current_app_user_id() as current_id_inactive;

-- Test UNIQUE constraint
RESET ROLE;
DO $$ BEGIN 
  INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid) VALUES
  ('DUP-1', 'Dup', 'dup', 'dup', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111');
  RAISE NOTICE 'UNIQUE CONSTRAINT FAILED (UNEXPECTED)';
EXCEPTION WHEN unique_violation THEN
  RAISE NOTICE 'UNIQUE CONSTRAINT TRIGGERED (EXPECTED)';
END $$;

-- Inspect Metadata
RESET ROLE;
SELECT proname, proowner::regrole, prosecdef, provolatile, proconfig 
FROM pg_proc 
WHERE proname IN ('current_app_user_id', 'is_admin');
