-- Setup Test Data
RESET ROLE;
TRUNCATE public.reservations CASCADE;
TRUNCATE public.app_users CASCADE;

-- Insert users
INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid) VALUES
('SALES-001', 'Sales A', 'salesA', 'salesA@example.com', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111'),
('SALES-002', 'Sales B', 'salesB', 'salesB@example.com', '', 'salesperson', true, now(), '22222222-2222-2222-2222-222222222222'),
('ADMIN-001', 'Admin', 'admin', 'admin@example.com', '', 'admin', true, now(), '33333333-3333-3333-3333-333333333333');

-- Insert initial reservations
INSERT INTO public.reservations (id, product_id, product_name, product_code, quantity, reserved_by_id, reserved_by_name, reserved_date, expiry_date, status) VALUES
('RES-A-1', 'PROD-1', 'Prod 1', 'P1', 1, 'SALES-001', 'Sales A', now(), now() + interval '1 day', 'ACTIVE'),
('RES-B-1', 'PROD-2', 'Prod 2', 'P2', 1, 'SALES-002', 'Sales B', now(), now() + interval '1 day', 'ACTIVE');

-----------------------------------------
-- 1. Test unauthenticated access (anon)
-----------------------------------------
SET ROLE anon;

-- Test Direct Selects (anon)
DO $$ BEGIN PERFORM * FROM public.reservations; RAISE NOTICE 'ANON RESERVATION SELECT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON RESERVATION SELECT DENIED (EXPECTED)'; END $$;
-- Test Direct Insert (anon)
DO $$ BEGIN INSERT INTO public.reservations (id, product_id, product_name, product_code, quantity, reserved_by_id, reserved_by_name, reserved_date, expiry_date, status) VALUES ('ANON', 'P', 'P', 'P', 1, 'SALES-001', 'A', now(), now(), 'ACTIVE'); RAISE NOTICE 'ANON RESERVATION INSERT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON RESERVATION INSERT DENIED (EXPECTED)'; END $$;


-----------------------------------------
-- 2. Test Salesperson A (authenticated non-admin)
-----------------------------------------
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}'; -- SALES-001

-- Should read ALL reservations (Warning workflow requirement)
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.reservations;
  IF count = 2 THEN RAISE NOTICE 'SALES A RESERVATION READ ALL ALLOWED (EXPECTED FOR WARNING WORKFLOW)'; ELSE RAISE NOTICE 'SALES A RESERVATION READ FAILED: Expected 2, got % (UNEXPECTED)', count; END IF;
END $$;

-- Update cross-user spoofing (Should fail to update Sales B's reservation)
DO $$ 
BEGIN 
  UPDATE public.reservations SET status = 'CANCELLED' WHERE id = 'RES-B-1';
  IF FOUND THEN
      RAISE NOTICE 'SALES A DIRECT UPDATE SALES B RESERVATION ALLOWED (UNEXPECTED)';
  ELSE
      RAISE NOTICE 'SALES A DIRECT UPDATE SALES B RESERVATION DENIED (EXPECTED - ZERO ROWS UPDATED)';
  END IF;
END $$;

-- Delete cross-user (Should fail to delete Sales B's reservation)
DO $$ 
BEGIN 
  DELETE FROM public.reservations WHERE id = 'RES-B-1';
  IF FOUND THEN
      RAISE NOTICE 'SALES A DIRECT DELETE SALES B RESERVATION ALLOWED (UNEXPECTED)';
  ELSE
      RAISE NOTICE 'SALES A DIRECT DELETE SALES B RESERVATION DENIED (EXPECTED - ZERO ROWS DELETED)';
  END IF;
END $$;

-- Insert spoofing (Should fail to insert with Sales B's ID)
DO $$ 
BEGIN 
  INSERT INTO public.reservations (id, product_id, product_name, product_code, quantity, reserved_by_id, reserved_by_name, reserved_date, expiry_date, status) 
  VALUES ('RES-SPOOF-1', 'PROD-3', 'Prod 3', 'P3', 1, 'SALES-002', 'Sales B', now(), now() + interval '1 day', 'ACTIVE');
  RAISE NOTICE 'SALES A INSERT FOR SALES B ALLOWED (UNEXPECTED)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'SALES A INSERT FOR SALES B DENIED (EXPECTED)';
END $$;

-- Update spoofing (Should fail to reassign own reservation to Sales B)
DO $$ 
BEGIN 
  UPDATE public.reservations SET reserved_by_id = 'SALES-002' WHERE id = 'RES-A-1';
  RAISE NOTICE 'SALES A REASSIGN TO SALES B ALLOWED (UNEXPECTED)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'SALES A REASSIGN TO SALES B DENIED (EXPECTED)';
END $$;

-- Valid Insert (Should succeed to insert own reservation)
DO $$ 
BEGIN 
  INSERT INTO public.reservations (id, product_id, product_name, product_code, quantity, reserved_by_id, reserved_by_name, reserved_date, expiry_date, status) 
  VALUES ('RES-A-2', 'PROD-4', 'Prod 4', 'P4', 1, 'SALES-001', 'Sales A', now(), now() + interval '1 day', 'ACTIVE');
  RAISE NOTICE 'SALES A VALID INSERT ALLOWED (EXPECTED)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'SALES A VALID INSERT DENIED (UNEXPECTED)';
END $$;

-- Valid Update (Should succeed to update own reservation status)
DO $$ 
BEGIN 
  UPDATE public.reservations SET status = 'CANCELLED' WHERE id = 'RES-A-1';
  IF FOUND THEN
      RAISE NOTICE 'SALES A VALID UPDATE ALLOWED (EXPECTED)';
  ELSE
      RAISE NOTICE 'SALES A VALID UPDATE DENIED (UNEXPECTED - ZERO ROWS UPDATED)';
  END IF;
END $$;


-----------------------------------------
-- 3. Test Admin (authenticated admin)
-----------------------------------------
SET request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333"}'; -- ADMIN-001

-- Should read all reservations
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.reservations;
  IF count = 3 THEN RAISE NOTICE 'ADMIN RESERVATION READ ALL ALLOWED (EXPECTED)'; ELSE RAISE NOTICE 'ADMIN RESERVATION READ FAILED (UNEXPECTED)'; END IF;
END $$;

-- Valid Admin Update (Should succeed to update Sales B's reservation)
DO $$ 
BEGIN 
  UPDATE public.reservations SET status = 'COMPLETED' WHERE id = 'RES-B-1';
  IF FOUND THEN
      RAISE NOTICE 'ADMIN UPDATE SALES B RESERVATION ALLOWED (EXPECTED)';
  ELSE
      RAISE NOTICE 'ADMIN UPDATE SALES B RESERVATION DENIED (UNEXPECTED - ZERO ROWS UPDATED)';
  END IF;
END $$;

RESET ROLE;
