-- Allow revision creation from any family member and content-only edits to
-- original quotations while preserving immutable revision history.

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

  IF OLD.revision_no > 0 THEN
    RAISE EXCEPTION 'Saved quotation revisions are immutable.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_quotation(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
  v_number text;
  v_item jsonb;
  v_position integer := 0;
  v_created_at timestamptz;
  v_current_user text := public.current_app_user_id();
  v_is_admin boolean := public.is_admin();
  v_target_salesperson text;
  v_existing_salesperson text;
  v_existing_number text;
  v_existing_revision_no integer;
BEGIN
  v_target_salesperson := COALESCE(p_payload->>'salespersonId', '');

  v_created_at := COALESCE(
    NULLIF(p_payload->>'createdDate', '')::timestamptz,
    now()
  );

  IF NULLIF(p_payload->>'id', '') IS NULL THEN
    v_id := gen_random_uuid();
    IF NOT v_is_admin THEN
      IF v_target_salesperson <> v_current_user THEN
        RAISE EXCEPTION
          'Unauthorized: Cannot create quotations for other salespersons.';
      END IF;
      v_target_salesperson := v_current_user;
    END IF;

    v_number := NULLIF(p_payload->>'quotationNumber', '');
    IF v_number IS NULL OR v_number LIKE 'DRAFT-%' THEN
      v_number := public.allocate_quotation_number(
        v_target_salesperson,
        EXTRACT(year FROM (v_created_at AT TIME ZONE 'UTC'))::integer
      );
    END IF;
  ELSE
    v_id := (p_payload->>'id')::uuid;
    SELECT
      quotation.salesperson_id,
      quotation.quotation_number,
      quotation.revision_no
    INTO
      v_existing_salesperson,
      v_existing_number,
      v_existing_revision_no
    FROM public.quotations quotation
    WHERE quotation.id = v_id;

    IF v_existing_revision_no > 0 THEN
      RAISE EXCEPTION 'Saved quotation revisions are immutable.';
    END IF;

    IF NOT v_is_admin THEN
      IF v_existing_salesperson IS NOT NULL
         AND v_existing_salesperson <> v_current_user THEN
        RAISE EXCEPTION
          'Unauthorized: Cannot modify quotations belonging to other salespersons.';
      END IF;
      IF v_target_salesperson <> v_current_user THEN
        RAISE EXCEPTION
          'Unauthorized: Cannot reassign quotations to other salespersons.';
      END IF;
      v_target_salesperson := v_current_user;
    END IF;

    IF v_existing_number IS NOT NULL
       AND v_existing_number NOT LIKE 'DRAFT-%' THEN
      v_number := v_existing_number;
    ELSE
      v_number := NULLIF(p_payload->>'quotationNumber', '');
      IF v_number IS NULL OR v_number LIKE 'DRAFT-%' THEN
        v_number := public.allocate_quotation_number(
          v_target_salesperson,
          EXTRACT(year FROM (v_created_at AT TIME ZONE 'UTC'))::integer
        );
      END IF;
    END IF;
  END IF;

  INSERT INTO public.quotations (
    id,
    quotation_number,
    salesperson_id,
    customer_name,
    customer_company,
    customer_phone,
    customer_email,
    project_location,
    delivery_charges,
    installation_charges,
    other_charges,
    overall_discount,
    vat_percentage,
    customer_notes,
    internal_notes,
    status,
    is_stock_out_processed,
    valid_until,
    expected_delivery,
    created_at,
    updated_at
  )
  VALUES (
    v_id,
    v_number,
    v_target_salesperson,
    COALESCE(p_payload #>> '{customerInfo,name}', ''),
    COALESCE(p_payload #>> '{customerInfo,company}', ''),
    COALESCE(p_payload #>> '{customerInfo,phone}', ''),
    COALESCE(p_payload #>> '{customerInfo,email}', ''),
    COALESCE(p_payload #>> '{customerInfo,projectLocation}', ''),
    COALESCE(NULLIF(p_payload #>> '{charges,deliveryCharges}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,installationCharges}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,otherCharges}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,overallDiscount}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,vatPercentage}', '')::numeric, 5),
    COALESCE(p_payload->>'customerNotes', ''),
    COALESCE(p_payload->>'internalNotes', ''),
    COALESCE(p_payload->>'status', 'draft'),
    COALESCE((p_payload->>'isStockOutProcessed')::boolean, false),
    COALESCE(NULLIF(p_payload->>'validUntil', '')::timestamptz, now()),
    NULLIF(p_payload->>'expectedDelivery', '')::timestamptz,
    v_created_at,
    COALESCE(NULLIF(p_payload->>'modifiedDate', '')::timestamptz, now())
  )
  ON CONFLICT (id) DO UPDATE SET
    quotation_number = excluded.quotation_number,
    salesperson_id = excluded.salesperson_id,
    customer_name = excluded.customer_name,
    customer_company = excluded.customer_company,
    customer_phone = excluded.customer_phone,
    customer_email = excluded.customer_email,
    project_location = excluded.project_location,
    delivery_charges = excluded.delivery_charges,
    installation_charges = excluded.installation_charges,
    other_charges = excluded.other_charges,
    overall_discount = excluded.overall_discount,
    vat_percentage = excluded.vat_percentage,
    customer_notes = excluded.customer_notes,
    internal_notes = excluded.internal_notes,
    status = excluded.status,
    is_stock_out_processed = excluded.is_stock_out_processed,
    valid_until = excluded.valid_until,
    expected_delivery = excluded.expected_delivery,
    updated_at = excluded.updated_at;

  DELETE FROM public.quotation_items WHERE quotation_id = v_id;

  FOR v_item IN
    SELECT value
    FROM pg_catalog.jsonb_array_elements(
      COALESCE(p_payload->'lineItems', '[]'::jsonb)
    )
  LOOP
    INSERT INTO public.quotation_items (
      id,
      quotation_id,
      product_id,
      product_code,
      name,
      brand,
      condition,
      unit_price,
      quantity,
      discount,
      description,
      is_custom,
      is_vat_applicable,
      image_storage_path,
      image_id,
      sort_order
    )
    VALUES (
      COALESCE(NULLIF(v_item->>'id', '')::uuid, gen_random_uuid()),
      v_id,
      NULLIF(v_item->>'productId', '')::uuid,
      NULLIF(v_item->>'productCode', ''),
      COALESCE(v_item->>'name', ''),
      COALESCE(v_item->>'brand', ''),
      NULLIF(v_item->>'condition', ''),
      COALESCE(NULLIF(v_item->>'unitPrice', '')::numeric, 0),
      GREATEST(COALESCE(NULLIF(v_item->>'quantity', '')::integer, 1), 1),
      COALESCE(NULLIF(v_item->>'discount', '')::numeric, 0),
      NULLIF(v_item->>'description', ''),
      COALESCE((v_item->>'isCustom')::boolean, false),
      COALESCE((v_item->>'isVatApplicable')::boolean, true),
      NULLIF(v_item->>'imagePath', ''),
      NULLIF(v_item->>'imageId', ''),
      v_position
    );
    v_position := v_position + 1;
  END LOOP;

  RETURN pg_catalog.jsonb_build_object(
    'id', v_id::text,
    'quotationNumber', v_number
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN pg_catalog.jsonb_build_object('error', sqlerrm);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_quotation_revision(
  p_source_quotation_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_current_user text := public.current_app_user_id();
  v_is_admin boolean := public.is_admin();
  v_source_base_id uuid;
  v_source_number text;
  v_source_salesperson text;
  v_base_id uuid;
  v_base_number text;
  v_base_salesperson text;
  v_latest_revision_no integer;
  v_next_revision_no integer;
  v_new_id uuid := gen_random_uuid();
  v_item jsonb;
  v_position integer := 0;
BEGIN
  SELECT
    quotation.base_quotation_id,
    quotation.quotation_number,
    quotation.salesperson_id
  INTO
    v_source_base_id,
    v_source_number,
    v_source_salesperson
  FROM public.quotations quotation
  WHERE quotation.id = p_source_quotation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source quotation was not found or is not accessible.';
  END IF;

  IF NOT v_is_admin AND v_source_salesperson <> v_current_user THEN
    RAISE EXCEPTION
      'Unauthorized: Cannot revise quotations belonging to other salespersons.';
  END IF;

  v_base_id := COALESCE(v_source_base_id, p_source_quotation_id);

  SELECT
    quotation.quotation_number,
    quotation.salesperson_id
  INTO
    v_base_number,
    v_base_salesperson
  FROM public.quotations quotation
  WHERE quotation.id = v_base_id
    AND quotation.base_quotation_id IS NULL
    AND quotation.revision_no = 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The original quotation for this revision was not found.';
  END IF;

  IF v_base_number <> v_source_number
     OR v_base_salesperson <> v_source_salesperson THEN
    RAISE EXCEPTION 'Quotation revision family is inconsistent.';
  END IF;

  SELECT MAX(quotation.revision_no)
  INTO v_latest_revision_no
  FROM public.quotations quotation
  WHERE quotation.id = v_base_id
     OR quotation.base_quotation_id = v_base_id;

  v_next_revision_no := v_latest_revision_no + 1;

  INSERT INTO public.quotations (
    id,
    quotation_number,
    base_quotation_id,
    revision_no,
    salesperson_id,
    customer_name,
    customer_company,
    customer_phone,
    customer_email,
    project_location,
    delivery_charges,
    installation_charges,
    other_charges,
    overall_discount,
    vat_percentage,
    customer_notes,
    internal_notes,
    status,
    is_stock_out_processed,
    valid_until,
    expected_delivery,
    created_at,
    updated_at
  )
  VALUES (
    v_new_id,
    v_base_number,
    v_base_id,
    v_next_revision_no,
    v_base_salesperson,
    COALESCE(p_payload #>> '{customerInfo,name}', ''),
    COALESCE(p_payload #>> '{customerInfo,company}', ''),
    COALESCE(p_payload #>> '{customerInfo,phone}', ''),
    COALESCE(p_payload #>> '{customerInfo,email}', ''),
    COALESCE(p_payload #>> '{customerInfo,projectLocation}', ''),
    COALESCE(NULLIF(p_payload #>> '{charges,deliveryCharges}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,installationCharges}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,otherCharges}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,overallDiscount}', '')::numeric, 0),
    COALESCE(NULLIF(p_payload #>> '{charges,vatPercentage}', '')::numeric, 5),
    COALESCE(p_payload->>'customerNotes', ''),
    COALESCE(p_payload->>'internalNotes', ''),
    COALESCE(p_payload->>'status', 'draft'),
    COALESCE((p_payload->>'isStockOutProcessed')::boolean, false),
    COALESCE(NULLIF(p_payload->>'validUntil', '')::timestamptz, now()),
    NULLIF(p_payload->>'expectedDelivery', '')::timestamptz,
    now(),
    now()
  );

  FOR v_item IN
    SELECT value
    FROM pg_catalog.jsonb_array_elements(
      COALESCE(p_payload->'lineItems', '[]'::jsonb)
    )
  LOOP
    INSERT INTO public.quotation_items (
      id,
      quotation_id,
      product_id,
      product_code,
      name,
      brand,
      condition,
      unit_price,
      quantity,
      discount,
      description,
      is_custom,
      is_vat_applicable,
      image_storage_path,
      image_id,
      sort_order
    )
    VALUES (
      gen_random_uuid(),
      v_new_id,
      NULLIF(v_item->>'productId', '')::uuid,
      NULLIF(v_item->>'productCode', ''),
      COALESCE(v_item->>'name', ''),
      COALESCE(v_item->>'brand', ''),
      NULLIF(v_item->>'condition', ''),
      COALESCE(NULLIF(v_item->>'unitPrice', '')::numeric, 0),
      GREATEST(COALESCE(NULLIF(v_item->>'quantity', '')::integer, 1), 1),
      COALESCE(NULLIF(v_item->>'discount', '')::numeric, 0),
      NULLIF(v_item->>'description', ''),
      COALESCE((v_item->>'isCustom')::boolean, false),
      COALESCE((v_item->>'isVatApplicable')::boolean, true),
      NULLIF(v_item->>'imagePath', ''),
      NULLIF(v_item->>'imageId', ''),
      v_position
    );
    v_position := v_position + 1;
  END LOOP;

  RETURN pg_catalog.jsonb_build_object(
    'id', v_new_id::text,
    'quotation_number', v_base_number,
    'base_quotation_id', v_base_id::text,
    'revision_no', v_next_revision_no
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN pg_catalog.jsonb_build_object(
      'error', 'A newer quotation revision already exists. Reload and try again.'
    );
  WHEN OTHERS THEN
    RETURN pg_catalog.jsonb_build_object('error', sqlerrm);
END;
$$;
