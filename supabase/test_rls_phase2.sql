-- Setup Test Data
RESET ROLE;
TRUNCATE public.stock_movements CASCADE;
TRUNCATE public.products CASCADE;
TRUNCATE public.app_users CASCADE;

-- Insert users
INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid) VALUES
('SALES-001', 'Sales A', 'salesA', 'salesA@example.com', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111'),
('ADMIN-001', 'Admin', 'admin', 'admin@example.com', '', 'admin', true, now(), '33333333-3333-3333-3333-333333333333');

-- Insert product
INSERT INTO public.products (id, name, product_code, normalized_product_code, opening_stock, selling_price, min_stock_level, created_at, updated_at) VALUES
('00000000-0000-0000-0000-000000000001', 'Test Product', 'TEST-PROD', 'TEST-PROD', 10, 100, 5, now(), now());

-- Insert stock movement
INSERT INTO public.stock_movements (id, product_id, quantity, type, movement_date, reference, created_at, created_by) VALUES
('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 5, 'stockIn', now(), 'Initial Stock', now(), 'ADMIN-001');

-----------------------------------------
-- 1. Test unauthenticated access (anon)
-----------------------------------------
SET ROLE anon;

-- Test Product Select (anon)
DO $$ BEGIN PERFORM * FROM public.products; RAISE NOTICE 'ANON PRODUCT SELECT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON PRODUCT SELECT DENIED (EXPECTED)'; END $$;
-- Test Product Insert (anon)
DO $$ BEGIN INSERT INTO public.products(id, name, product_code, normalized_product_code, opening_stock, selling_price, min_stock_level) VALUES ('00000000-0000-0000-0000-000000000002', 'Anon Prod', 'ANON', 'ANON', 0, 0, 0); RAISE NOTICE 'ANON PRODUCT INSERT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON PRODUCT INSERT DENIED (EXPECTED)'; END $$;

-- Test Stock Movement Select (anon)
DO $$ BEGIN PERFORM * FROM public.stock_movements; RAISE NOTICE 'ANON STOCK SELECT ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON STOCK SELECT DENIED (EXPECTED)'; END $$;

-- Test get_current_stock (anon)
DO $$ BEGIN PERFORM public.get_current_stock('00000000-0000-0000-0000-000000000001'); RAISE NOTICE 'ANON get_current_stock ALLOWED (UNEXPECTED)'; EXCEPTION WHEN INSUFFICIENT_PRIVILEGE THEN RAISE NOTICE 'ANON get_current_stock DENIED (EXPECTED)'; END $$;

-----------------------------------------
-- 2. Test Salesperson (authenticated non-admin)
-----------------------------------------
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}'; -- SALES-001

-- Should read products
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.products;
  IF count = 0 THEN RAISE NOTICE 'SALES PRODUCT READ FAILED (UNEXPECTED)'; ELSE RAISE NOTICE 'SALES PRODUCT READ ALLOWED (EXPECTED)'; END IF;
END $$;

-- Should fail to insert product (RLS policy rejects)
DO $$ 
BEGIN 
  INSERT INTO public.products(id, name, product_code, normalized_product_code, opening_stock, selling_price, min_stock_level) VALUES ('00000000-0000-0000-0000-000000000002', 'Sales Prod', 'SALES', 'SALES', 0, 0, 0); 
  RAISE NOTICE 'SALES PRODUCT INSERT ALLOWED (UNEXPECTED)'; 
EXCEPTION WHEN OTHERS THEN 
  RAISE NOTICE 'SALES PRODUCT INSERT DENIED (EXPECTED)'; 
END $$;

-- Should read stock movements
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.stock_movements;
  IF count = 0 THEN RAISE NOTICE 'SALES STOCK READ FAILED (UNEXPECTED)'; ELSE RAISE NOTICE 'SALES STOCK READ ALLOWED (EXPECTED)'; END IF;
END $$;

-- Should get current stock
DO $$
DECLARE stock int;
BEGIN 
  SELECT public.get_current_stock('00000000-0000-0000-0000-000000000001') INTO stock;
  IF stock = 15 THEN RAISE NOTICE 'SALES get_current_stock ALLOWED (EXPECTED)'; ELSE RAISE NOTICE 'SALES get_current_stock WRONG CALCULATION (UNEXPECTED)'; END IF;
END $$;

-----------------------------------------
-- 3. Test Admin (authenticated admin)
-----------------------------------------
SET request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333"}'; -- ADMIN-001

-- Should read products
DO $$
DECLARE count int;
BEGIN 
  SELECT COUNT(*) INTO count FROM public.products;
  IF count = 0 THEN RAISE NOTICE 'ADMIN PRODUCT READ FAILED (UNEXPECTED)'; ELSE RAISE NOTICE 'ADMIN PRODUCT READ ALLOWED (EXPECTED)'; END IF;
END $$;

-- Should insert product
DO $$ 
BEGIN 
  INSERT INTO public.products(id, name, product_code, normalized_product_code, opening_stock, selling_price, min_stock_level, created_at, updated_at) VALUES ('00000000-0000-0000-0000-000000000003', 'Admin Prod', 'ADMIN', 'ADMIN', 0, 0, 0, now(), now()); 
  RAISE NOTICE 'ADMIN PRODUCT INSERT ALLOWED (EXPECTED)'; 
EXCEPTION WHEN OTHERS THEN 
  RAISE NOTICE 'ADMIN PRODUCT INSERT DENIED (UNEXPECTED): %', SQLERRM; 
END $$;

-- Should insert stock movement
DO $$ 
BEGIN 
  INSERT INTO public.stock_movements (id, product_id, quantity, type, movement_date, reference, created_at, created_by) VALUES ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 2, 'stockOut', now(), 'Admin Out', now(), 'ADMIN-001');
  RAISE NOTICE 'ADMIN STOCK INSERT ALLOWED (EXPECTED)'; 
EXCEPTION WHEN OTHERS THEN 
  RAISE NOTICE 'ADMIN STOCK INSERT DENIED (UNEXPECTED): %', SQLERRM; 
END $$;

-- Should update stock movement
DO $$ 
BEGIN 
  UPDATE public.stock_movements SET reference = 'Updated Admin Out' WHERE id = '00000000-0000-0000-0000-000000000002';
  RAISE NOTICE 'ADMIN STOCK UPDATE ALLOWED (EXPECTED)'; 
EXCEPTION WHEN OTHERS THEN 
  RAISE NOTICE 'ADMIN STOCK UPDATE DENIED (UNEXPECTED): %', SQLERRM; 
END $$;

-- Should get current stock
DO $$
DECLARE stock int;
BEGIN 
  SELECT public.get_current_stock('00000000-0000-0000-0000-000000000001') INTO stock;
  IF stock = 13 THEN RAISE NOTICE 'ADMIN get_current_stock ALLOWED (EXPECTED)'; ELSE RAISE NOTICE 'ADMIN get_current_stock WRONG CALCULATION (UNEXPECTED)'; END IF;
END $$;

RESET ROLE;
