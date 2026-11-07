-- Process quotation stock-outs on the server so stock movements and the
-- quotation processing flag either commit together or roll back together.

-- Admins need read-only access to salesperson quotations for the admin-only
-- stock-out workflow. Existing owner policies continue to isolate salespeople.
DROP POLICY IF EXISTS "Allow admins read quotations for stock processing"
  ON public.quotations;
CREATE POLICY "Allow admins read quotations for stock processing"
  ON public.quotations
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Allow admins read quotation items for stock processing"
  ON public.quotation_items;
CREATE POLICY "Allow admins read quotation items for stock processing"
  ON public.quotation_items
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

-- A saved revision remains content-immutable, but its operational stock-out
-- flag may move from false to true. A processed quotation can never be reset.
CREATE OR REPLACE FUNCTION public.protect_quotation_revision_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.quotation_number IS DISTINCT FROM OLD.quotation_number
     OR NEW.base_quotation_id IS DISTINCT FROM OLD.base_quotation_id
     OR NEW.revision_no IS DISTINCT FROM OLD.revision_no THEN
    RAISE EXCEPTION
      'Quotation identity, number, base quotation, and revision number are immutable.';
  END IF;

  IF OLD.is_stock_out_processed
     AND NOT NEW.is_stock_out_processed THEN
    RAISE EXCEPTION 'A processed quotation cannot be reset for stock out.';
  END IF;

  IF OLD.revision_no > 0
     AND (
       pg_catalog.to_jsonb(NEW)
         - 'is_stock_out_processed'
         - 'updated_at'
     ) IS DISTINCT FROM (
       pg_catalog.to_jsonb(OLD)
         - 'is_stock_out_processed'
         - 'updated_at'
     ) THEN
    RAISE EXCEPTION 'Saved quotation revisions are immutable.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.process_quotation_stock_out(
  p_quotation_number text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id text;
  v_clean_number text := pg_catalog.btrim(p_quotation_number);
  v_quotation_id uuid;
  v_quotation_number text;
  v_already_processed boolean;
  v_product_id uuid;
  v_product_name text;
  v_required integer;
  v_available integer;
  v_deducted_count integer := 0;
  v_reservation_count integer := 0;
  v_movements jsonb := '[]'::jsonb;
  v_now timestamptz := pg_catalog.now();
BEGIN
  -- SECURITY DEFINER is required because salesperson quotations remain
  -- owner-only for writes. Authorization is therefore enforced here before
  -- any quotation lookup, preventing existence disclosure to non-admins.
  IF auth.uid() IS NULL OR NOT COALESCE(public.is_admin(), false) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Not authorized to process quotation stock out.';
  END IF;

  v_actor_id := public.current_app_user_id();

  IF v_clean_number IS NULL OR v_clean_number = '' THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Quotation number cannot be empty.';
  END IF;

  -- Revisions share a quotation number. Process the latest saved revision and
  -- serialize duplicate/concurrent requests on that exact quotation row.
  SELECT
    quotation.id,
    quotation.quotation_number,
    quotation.is_stock_out_processed
  INTO
    v_quotation_id,
    v_quotation_number,
    v_already_processed
  FROM public.quotations quotation
  WHERE quotation.quotation_number = v_clean_number
  ORDER BY quotation.revision_no DESC, quotation.created_at DESC, quotation.id
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quotation not found.';
  END IF;

  IF v_already_processed THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', true,
      'already_processed', true,
      'quotation_id', v_quotation_id::text,
      'quotation_number', v_quotation_number,
      'deducted_count', 0,
      'movements', '[]'::jsonb
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.quotation_items item
    WHERE item.quotation_id = v_quotation_id
      AND NOT item.is_custom
      AND item.product_id IS NOT NULL
      AND item.quantity > 0
  ) THEN
    RAISE EXCEPTION 'No eligible stock items found in this quotation.';
  END IF;

  -- Product rows are locked in a stable order. This serializes concurrent
  -- quotation deductions that touch the same products and avoids deadlocks.
  PERFORM product.id
  FROM public.products product
  WHERE product.id IN (
    SELECT DISTINCT item.product_id
    FROM public.quotation_items item
    WHERE item.quotation_id = v_quotation_id
      AND NOT item.is_custom
      AND item.product_id IS NOT NULL
      AND item.quantity > 0
  )
  ORDER BY product.id
  FOR UPDATE;

  -- Validate aggregate demand per product before inserting any movement. This
  -- also handles a quotation containing the same product on multiple lines.
  FOR v_product_id, v_product_name, v_required IN
    SELECT
      item.product_id,
      MIN(item.name),
      SUM(item.quantity)::integer
    FROM public.quotation_items item
    WHERE item.quotation_id = v_quotation_id
      AND NOT item.is_custom
      AND item.product_id IS NOT NULL
      AND item.quantity > 0
    GROUP BY item.product_id
    ORDER BY item.product_id
  LOOP
    SELECT
      product.opening_stock
      + COALESCE(
          SUM(
            CASE
              WHEN movement.type = 'stockIn' THEN movement.quantity
              WHEN movement.type = 'stockOut' THEN -movement.quantity
              ELSE 0
            END
          ),
          0
        )::integer
    INTO v_available
    FROM public.products product
    LEFT JOIN public.stock_movements movement
      ON movement.product_id = product.id
    WHERE product.id = v_product_id
    GROUP BY product.opening_stock;

    IF v_available IS NULL THEN
      RAISE EXCEPTION 'Product "%" not found in database.', v_product_name;
    END IF;

    IF v_available < v_required THEN
      RAISE EXCEPTION
        'Insufficient stock for "%". Available: %, Required: %.',
        v_product_name,
        v_available,
        v_required;
    END IF;
  END LOOP;

  WITH inserted AS (
    INSERT INTO public.stock_movements (
      id,
      product_id,
      type,
      quantity,
      reference,
      movement_date,
      created_at,
      created_by
    )
    SELECT
      gen_random_uuid(),
      item.product_id,
      'stockOut',
      item.quantity,
      'Reason: Quotation Stock Out | Quotation: ' || v_quotation_number,
      v_now,
      v_now,
      v_actor_id
    FROM public.quotation_items item
    WHERE item.quotation_id = v_quotation_id
      AND NOT item.is_custom
      AND item.product_id IS NOT NULL
      AND item.quantity > 0
    ORDER BY item.sort_order, item.id
    RETURNING
      id,
      product_id,
      type,
      quantity,
      reference,
      movement_date,
      created_at,
      created_by
  )
  SELECT
    COUNT(*)::integer,
    COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', inserted.id::text,
          'product_id', inserted.product_id::text,
          'type', inserted.type,
          'quantity', inserted.quantity,
          'reference', inserted.reference,
          'movement_date', inserted.movement_date,
          'created_at', inserted.created_at,
          'created_by', inserted.created_by
        )
        ORDER BY inserted.created_at, inserted.id
      ),
      '[]'::jsonb
    )
  INTO v_deducted_count, v_movements
  FROM inserted;

  -- Preserve the existing reservation behavior, but keep the authoritative
  -- reservation state in the same server transaction as the deduction.
  UPDATE public.reservations reservation
  SET
    status = 'COMPLETED',
    updated_at = v_now
  WHERE reservation.status = 'ACTIVE'
    AND reservation.product_id IN (
      SELECT DISTINCT item.product_id::text
      FROM public.quotation_items item
      WHERE item.quotation_id = v_quotation_id
        AND NOT item.is_custom
        AND item.product_id IS NOT NULL
        AND item.quantity > 0
    );
  GET DIAGNOSTICS v_reservation_count = ROW_COUNT;

  UPDATE public.quotations
  SET
    is_stock_out_processed = true,
    updated_at = v_now
  WHERE id = v_quotation_id;

  RETURN pg_catalog.jsonb_build_object(
    'success', true,
    'already_processed', false,
    'quotation_id', v_quotation_id::text,
    'quotation_number', v_quotation_number,
    'deducted_count', v_deducted_count,
    'reservation_count', v_reservation_count,
    'processed_at', v_now,
    'movements', v_movements
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_quotation_stock_out(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.process_quotation_stock_out(text)
  TO authenticated;
