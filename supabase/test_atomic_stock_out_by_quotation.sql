-- Run after 20261106000000_atomic_stock_out_by_quotation.sql in a disposable
-- database. The transaction is always rolled back.
BEGIN;

RESET ROLE;

INSERT INTO public.app_users (
  id,
  name,
  username,
  email,
  password_hash,
  role,
  is_active,
  created_at,
  supabase_uid,
  quotation_code
)
VALUES
  (
    'STOCK-ADMIN',
    'Stock Admin',
    'stock-admin-regression',
    'stock-admin-regression@example.com',
    '',
    'admin',
    true,
    now(),
    '97000000-0000-0000-0000-000000000001',
    'SA'
  ),
  (
    'STOCK-SALES',
    'Stock Salesperson',
    'stock-sales-regression',
    'stock-sales-regression@example.com',
    '',
    'salesperson',
    true,
    now(),
    '97000000-0000-0000-0000-000000000002',
    'SS'
  );

INSERT INTO public.products (
  id,
  product_code,
  normalized_product_code,
  name,
  opening_stock
)
VALUES
  (
    '97100000-0000-0000-0000-000000000001',
    'STOCK-ATOMIC-1',
    'STOCK-ATOMIC-1',
    'Atomic Product',
    10
  ),
  (
    '97100000-0000-0000-0000-000000000002',
    'STOCK-ATOMIC-2',
    'STOCK-ATOMIC-2',
    'Insufficient Product',
    1
  );

INSERT INTO public.quotations (
  id,
  quotation_number,
  salesperson_id,
  customer_name,
  valid_until
)
VALUES (
  '97200000-0000-0000-0000-000000000001',
  'QT-STOCK-ATOMIC-26',
  'STOCK-SALES',
  'Original Customer',
  now() + interval '7 days'
);

INSERT INTO public.quotations (
  id,
  quotation_number,
  base_quotation_id,
  revision_no,
  salesperson_id,
  customer_name,
  valid_until
)
VALUES (
  '97200000-0000-0000-0000-000000000002',
  'QT-STOCK-ATOMIC-26',
  '97200000-0000-0000-0000-000000000001',
  1,
  'STOCK-SALES',
  'Revision Customer',
  now() + interval '7 days'
);

INSERT INTO public.quotations (
  id,
  quotation_number,
  salesperson_id,
  customer_name,
  valid_until
)
VALUES (
  '97200000-0000-0000-0000-000000000003',
  'QT-STOCK-FAIL-26',
  'STOCK-SALES',
  'Rollback Customer',
  now() + interval '7 days'
);

INSERT INTO public.quotations (
  id,
  quotation_number,
  salesperson_id,
  customer_name,
  valid_until
)
VALUES (
  '97200000-0000-0000-0000-000000000004',
  'QT-STOCK-ADMIN-ONLY-26',
  'STOCK-ADMIN',
  'Unauthorized Customer',
  now() + interval '7 days'
);

INSERT INTO public.quotation_items (
  id,
  quotation_id,
  product_id,
  name,
  quantity,
  sort_order
)
VALUES
  (
    '97300000-0000-0000-0000-000000000001',
    '97200000-0000-0000-0000-000000000002',
    '97100000-0000-0000-0000-000000000001',
    'Atomic Product',
    3,
    0
  ),
  (
    '97300000-0000-0000-0000-000000000002',
    '97200000-0000-0000-0000-000000000003',
    '97100000-0000-0000-0000-000000000001',
    'Atomic Product',
    2,
    0
  ),
  (
    '97300000-0000-0000-0000-000000000003',
    '97200000-0000-0000-0000-000000000003',
    '97100000-0000-0000-0000-000000000002',
    'Insufficient Product',
    2,
    1
  );

SET ROLE authenticated;
SET request.jwt.claims TO
  '{"sub": "97000000-0000-0000-0000-000000000001"}';

DO $$
DECLARE
  v_first jsonb;
  v_duplicate jsonb;
  v_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.quotations
    WHERE id = '97200000-0000-0000-0000-000000000002'
      AND salesperson_id = 'STOCK-SALES'
  ) THEN
    RAISE EXCEPTION 'Admin cannot read the salesperson quotation.';
  END IF;

  v_first := public.process_quotation_stock_out('QT-STOCK-ATOMIC-26');
  IF v_first->>'success' <> 'true'
     OR v_first->>'already_processed' <> 'false'
     OR (v_first->>'deducted_count')::integer <> 1 THEN
    RAISE EXCEPTION 'First stock-out returned an invalid result: %', v_first;
  END IF;

  IF NOT (
    SELECT is_stock_out_processed
    FROM public.quotations
    WHERE id = '97200000-0000-0000-0000-000000000002'
  ) OR (
    SELECT is_stock_out_processed
    FROM public.quotations
    WHERE id = '97200000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'The latest revision was not marked correctly.';
  END IF;

  SELECT COUNT(*)
  INTO v_count
  FROM public.stock_movements
  WHERE reference =
    'Reason: Quotation Stock Out | Quotation: QT-STOCK-ATOMIC-26';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one movement after first processing, got %.',
      v_count;
  END IF;

  v_duplicate := public.process_quotation_stock_out('QT-STOCK-ATOMIC-26');
  IF v_duplicate->>'already_processed' <> 'true'
     OR (v_duplicate->>'deducted_count')::integer <> 0 THEN
    RAISE EXCEPTION 'Duplicate processing was not idempotent: %', v_duplicate;
  END IF;

  SELECT COUNT(*)
  INTO v_count
  FROM public.stock_movements
  WHERE reference =
    'Reason: Quotation Stock Out | Quotation: QT-STOCK-ATOMIC-26';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Duplicate processing created extra movements.';
  END IF;

  BEGIN
    PERFORM public.process_quotation_stock_out('QT-STOCK-FAIL-26');
    RAISE EXCEPTION 'Insufficient-stock transaction unexpectedly succeeded.';
  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm NOT LIKE 'Insufficient stock for "Insufficient Product".%' THEN
        RAISE;
      END IF;
  END;

  IF (
    SELECT is_stock_out_processed
    FROM public.quotations
    WHERE id = '97200000-0000-0000-0000-000000000003'
  ) THEN
    RAISE EXCEPTION 'Failed transaction marked the quotation as processed.';
  END IF;

  SELECT COUNT(*)
  INTO v_count
  FROM public.stock_movements
  WHERE reference =
    'Reason: Quotation Stock Out | Quotation: QT-STOCK-FAIL-26';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Failed transaction left partial stock movements.';
  END IF;
END;
$$;

SET request.jwt.claims TO
  '{"sub": "97000000-0000-0000-0000-000000000002"}';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.quotations
    WHERE salesperson_id <> 'STOCK-SALES'
  ) THEN
    RAISE EXCEPTION 'Salesperson can read an unauthorized quotation.';
  END IF;

  BEGIN
    PERFORM public.process_quotation_stock_out('QT-STOCK-FAIL-26');
    RAISE EXCEPTION 'Salesperson was allowed to execute admin stock-out.';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

ROLLBACK;
