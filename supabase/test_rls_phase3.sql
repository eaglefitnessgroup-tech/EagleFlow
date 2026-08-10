-- Setup Test Data
RESET ROLE;
TRUNCATE public.quotation_items CASCADE;
TRUNCATE public.quotations CASCADE;
TRUNCATE public.app_users CASCADE;

-- Insert users
INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid) VALUES
('SALES-001', 'Sales A', 'salesA', 'salesA@example.com', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111'),
('SALES-002', 'Sales B', 'salesB', 'salesB@example.com', '', 'salesperson', true, now(), '22222222-2222-2222-2222-222222222222'),
('ADMIN-001', 'Admin', 'admin', 'admin@example.com', '', 'admin', true, now(), '33333333-3333-3333-3333-333333333333');

INSERT INTO public.quotations (id, quotation_number, salesperson_id, customer_name, customer_company, valid_until) VALUES
('00000000-0000-0000-0000-000000000001', 'QT-SALES-A-1', 'SALES-001', 'Cust A', 'Comp A', now()),
('00000000-0000-0000-0000-000000000002', 'QT-SALES-B-1', 'SALES-002', 'Cust B', 'Comp B', now());

INSERT INTO public.quotation_items (id, quotation_id, quantity, name, unit_price) VALUES
('11111111-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 1, 'Item 1', 100),
('22222222-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 2, 'Item 2', 200);

-----------------------------------------
-- 1. Test unauthenticated access (anon)
-----------------------------------------
SET ROLE anon;

-- Test Direct Selects (anon)
DO $$ BEGIN PERFORM * FROM public.quotations; RAISE NOTICE 'ANON QUOTATION SELECT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON QUOTATION SELECT DENIED (EXPECTED)'; END $$;
DO $$ BEGIN PERFORM * FROM public.quotation_items; RAISE NOTICE 'ANON QUOTATION_ITEMS SELECT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON QUOTATION_ITEMS SELECT DENIED (EXPECTED)'; END $$;

-- Test save_quotation RPC (anon)
DO $$ BEGIN PERFORM public.save_quotation('{"customerInfo": {"name": "Hacked"}}'::jsonb); RAISE NOTICE 'ANON save_quotation ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON save_quotation DENIED (EXPECTED)'; END $$;


-----------------------------------------
-- 2. Test Salesperson A (authenticated non-admin)
-----------------------------------------
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}'; -- SALES-001

-- Should read only own quotations
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.quotations;
  IF count != 1 THEN RAISE NOTICE 'SALES A QUOTATION READ FAILED: Expected 1, got % (UNEXPECTED)', count; ELSE RAISE NOTICE 'SALES A QUOTATION READ ISOLATED (EXPECTED)'; END IF;
END $$;

-- Should read only own quotation_items
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.quotation_items;
  IF count != 1 THEN RAISE NOTICE 'SALES A QUOTATION_ITEMS READ FAILED: Expected 1, got % (UNEXPECTED)', count; ELSE RAISE NOTICE 'SALES A QUOTATION_ITEMS READ ISOLATED (EXPECTED)'; END IF;
END $$;

-- Direct UPDATE quotation_items cross-user spoofing (Should fail to update Sales B's item)
DO $$ 
BEGIN 
  UPDATE public.quotation_items SET name = 'Hacked' WHERE id = '22222222-0000-0000-0000-000000000002';
  IF FOUND THEN
      RAISE NOTICE 'SALES A DIRECT UPDATE SALES B QUOTATION_ITEMS ALLOWED (UNEXPECTED)';
  ELSE
      RAISE NOTICE 'SALES A DIRECT UPDATE SALES B QUOTATION_ITEMS DENIED (EXPECTED)';
  END IF;
END $$;

-- Direct INSERT quotation_items to Sales B's quotation (Should fail)
DO $$ 
BEGIN 
  INSERT INTO public.quotation_items (id, quotation_id, quantity, name, unit_price) VALUES ('33333333-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 1, 'Hacked Item', 100);
  RAISE NOTICE 'SALES A DIRECT INSERT INTO SALES B QUOTATION_ITEMS ALLOWED (UNEXPECTED)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'SALES A DIRECT INSERT INTO SALES B QUOTATION_ITEMS DENIED (EXPECTED)';
END $$;

-- Direct UPDATE cross-user spoofing (Should fail to update Sales B's quotation)
DO $$ 
BEGIN 
  UPDATE public.quotations SET customer_name = 'Hacked' WHERE id = '00000000-0000-0000-0000-000000000002';
  IF FOUND THEN
      RAISE NOTICE 'SALES A DIRECT UPDATE SALES B QUOTATION ALLOWED (UNEXPECTED)';
  ELSE
      RAISE NOTICE 'SALES A DIRECT UPDATE SALES B QUOTATION DENIED (EXPECTED - ZERO ROWS UPDATED)';
  END IF;
END $$;

-- RPC spoofing (CREATE) (Should fail to create for Sales B)
DO $$ 
DECLARE result jsonb;
BEGIN 
  SELECT public.save_quotation('{"salespersonId": "SALES-002", "customerInfo": {"name": "Hacked B"}}'::jsonb) INTO result;
  IF result->>'error' IS NOT NULL THEN
    RAISE NOTICE 'SALES A SPOOF CREATE RPC DENIED (EXPECTED): %', result->>'error';
  ELSE
    RAISE NOTICE 'SALES A SPOOF CREATE RPC ALLOWED (UNEXPECTED)';
  END IF;
END $$;

-- RPC spoofing (UPDATE) (Should fail to update Sales B's quotation)
DO $$ 
DECLARE result jsonb;
BEGIN 
  SELECT public.save_quotation('{"id": "00000000-0000-0000-0000-000000000002", "salespersonId": "SALES-002", "customerInfo": {"name": "Hacked B"}}'::jsonb) INTO result;
  IF result->>'error' IS NOT NULL THEN
    RAISE NOTICE 'SALES A SPOOF UPDATE RPC DENIED (EXPECTED): %', result->>'error';
  ELSE
    RAISE NOTICE 'SALES A SPOOF UPDATE RPC ALLOWED (UNEXPECTED)';
  END IF;
END $$;

-- RPC Valid (Should succeed to update own quotation)
DO $$ 
DECLARE result jsonb;
BEGIN 
  SELECT public.save_quotation('{"id": "00000000-0000-0000-0000-000000000001", "quotationNumber": "QT-SALES-A-1", "salespersonId": "SALES-001", "customerInfo": {"name": "Updated A"}}'::jsonb) INTO result;
  IF result->>'error' IS NOT NULL THEN
    RAISE NOTICE 'SALES A VALID UPDATE RPC FAILED (UNEXPECTED): %', result->>'error';
  ELSE
    RAISE NOTICE 'SALES A VALID UPDATE RPC ALLOWED (EXPECTED)';
  END IF;
END $$;

-- RPC Valid (Should succeed to create new quotation for self)
DO $$ 
DECLARE result jsonb;
BEGIN 
  SELECT public.save_quotation('{"salespersonId": "SALES-001", "customerInfo": {"name": "New A"}}'::jsonb) INTO result;
  IF result->>'error' IS NOT NULL THEN
    RAISE NOTICE 'SALES A VALID CREATE RPC FAILED (UNEXPECTED): %', result->>'error';
  ELSE
    RAISE NOTICE 'SALES A VALID CREATE RPC ALLOWED (EXPECTED)';
  END IF;
END $$;


-----------------------------------------
-- 3. Test Admin (authenticated admin)
-----------------------------------------
SET request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333"}'; -- ADMIN-001

-- Should read all quotations
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.quotations;
  IF count = 3 THEN RAISE NOTICE 'ADMIN QUOTATION READ ALL ALLOWED (EXPECTED)'; ELSE RAISE NOTICE 'ADMIN QUOTATION READ FAILED (UNEXPECTED)'; END IF;
END $$;

-- RPC Valid Admin update (Should succeed to update Sales B's quotation)
DO $$ 
DECLARE result jsonb;
BEGIN 
  SELECT public.save_quotation('{"id": "00000000-0000-0000-0000-000000000002", "quotationNumber": "QT-SALES-B-1", "salespersonId": "SALES-002", "customerInfo": {"name": "Admin Updated B"}}'::jsonb) INTO result;
  IF result->>'error' IS NOT NULL THEN
    RAISE NOTICE 'ADMIN UPDATE SALES B RPC FAILED (UNEXPECTED): %', result->>'error';
  ELSE
    RAISE NOTICE 'ADMIN UPDATE SALES B RPC ALLOWED (EXPECTED)';
  END IF;
END $$;

RESET ROLE;
