-- Setup Test Data
RESET ROLE;
TRUNCATE public.app_users CASCADE;
TRUNCATE public.quotations CASCADE;
TRUNCATE public.products CASCADE;

-- Insert users
INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid, quotation_code) VALUES
('SALES-001', 'Sales A', 'salesA', 'salesA@example.com', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111', 'T1'),
('ADMIN-001', 'Admin', 'admin', 'admin@example.com', '', 'admin', true, now(), '33333333-3333-3333-3333-333333333333', 'TA');

-- Insert initial product
INSERT INTO public.products (id, product_code, normalized_product_code, name, selling_price, is_vat_applicable, is_active, opening_stock) VALUES
('00000000-0000-0000-0000-000000000001', 'P1', 'P1', 'Prod 1', 10, true, true, 5);

-----------------------------------------
-- 1. Test unauthenticated access (anon)
-----------------------------------------
SET ROLE anon;

DO $$ BEGIN PERFORM public.is_admin(); RAISE NOTICE 'ANON is_admin() ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON is_admin() DENIED (EXPECTED)'; END $$;
DO $$ BEGIN PERFORM public.current_app_user_id(); RAISE NOTICE 'ANON current_app_user_id() ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON current_app_user_id() DENIED (EXPECTED)'; END $$;
DO $$ BEGIN PERFORM public.get_current_stock('00000000-0000-0000-0000-000000000001'::uuid); RAISE NOTICE 'ANON get_current_stock() ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON get_current_stock() DENIED (EXPECTED)'; END $$;
DO $$ BEGIN PERFORM public.save_quotation('{"customerInfo": {"name": "Hacked"}}'::jsonb); RAISE NOTICE 'ANON save_quotation() ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON save_quotation() DENIED (EXPECTED)'; END $$;

-----------------------------------------
-- 2. Test Salesperson A (authenticated non-admin)
-----------------------------------------
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}'; -- SALES-001

DO $$ 
BEGIN 
  IF public.is_admin() THEN
    RAISE NOTICE 'SALES A is_admin() RETURNED TRUE (UNEXPECTED ELEVATION)';
  ELSE
    RAISE NOTICE 'SALES A is_admin() RETURNED FALSE (EXPECTED)';
  END IF;
END $$;

DO $$ 
BEGIN 
  IF public.current_app_user_id() = 'SALES-001' THEN
    RAISE NOTICE 'SALES A current_app_user_id() RETURNED CORRECT ID (EXPECTED)';
  ELSE
    RAISE NOTICE 'SALES A current_app_user_id() RETURNED WRONG ID (UNEXPECTED)';
  END IF;
END $$;

DO $$ 
DECLARE
  stock int;
BEGIN 
  SELECT public.get_current_stock('00000000-0000-0000-0000-000000000001'::uuid) INTO stock;
  IF stock = 5 THEN
    RAISE NOTICE 'SALES A get_current_stock() RETURNED CORRECT STOCK (EXPECTED)';
  ELSE
    RAISE NOTICE 'SALES A get_current_stock() RETURNED WRONG STOCK (UNEXPECTED)';
  END IF;
END $$;

DO $$ 
DECLARE result jsonb;
BEGIN 
  SELECT public.save_quotation('{"salespersonId": "SALES-001", "customerInfo": {"name": "Test"}}'::jsonb) INTO result;
  IF result->>'error' IS NOT NULL THEN
    RAISE NOTICE 'SALES A save_quotation() FAILED (UNEXPECTED): %', result->>'error';
  ELSE
    RAISE NOTICE 'SALES A save_quotation() ALLOWED (EXPECTED)';
  END IF;
END $$;

-----------------------------------------
-- 3. Test Admin (authenticated admin)
-----------------------------------------
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333"}'; -- ADMIN-001

DO $$ 
BEGIN 
  IF public.is_admin() THEN
    RAISE NOTICE 'ADMIN is_admin() RETURNED TRUE (EXPECTED)';
  ELSE
    RAISE NOTICE 'ADMIN is_admin() RETURNED FALSE (UNEXPECTED DOWNGRADE)';
  END IF;
END $$;

RESET ROLE;
