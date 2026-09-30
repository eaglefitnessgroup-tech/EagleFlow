-- Stage 1: quotation revision persistence and history safety.

ALTER TABLE public.quotations
  ADD COLUMN base_quotation_id uuid NULL,
  ADD COLUMN revision_no integer NOT NULL DEFAULT 0;

ALTER TABLE public.quotations
  ADD CONSTRAINT quotations_base_quotation_id_fkey
    FOREIGN KEY (base_quotation_id)
    REFERENCES public.quotations(id)
    ON DELETE RESTRICT,
  ADD CONSTRAINT quotations_revision_no_check
    CHECK (revision_no >= 0),
  ADD CONSTRAINT quotations_revision_shape_check
    CHECK (
      (revision_no = 0 AND base_quotation_id IS NULL)
      OR
      (revision_no > 0 AND base_quotation_id IS NOT NULL)
    );

ALTER TABLE public.quotations
  DROP CONSTRAINT quotations_quotation_number_key;

ALTER TABLE public.quotations
  ADD CONSTRAINT quotations_number_revision_key
    UNIQUE (quotation_number, revision_no);

CREATE UNIQUE INDEX quotations_base_revision_key
  ON public.quotations (base_quotation_id, revision_no)
  WHERE base_quotation_id IS NOT NULL;

CREATE INDEX quotations_base_revision_idx
  ON public.quotations (base_quotation_id, revision_no);

CREATE OR REPLACE FUNCTION public.protect_quotation_revision_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.quotation_number IS DISTINCT FROM OLD.quotation_number
     OR NEW.base_quotation_id IS DISTINCT FROM OLD.base_quotation_id
     OR NEW.revision_no IS DISTINCT FROM OLD.revision_no THEN
    RAISE EXCEPTION
      'Quotation number, base quotation, and revision number are immutable.';
  END IF;

  IF OLD.revision_no > 0 THEN
    RAISE EXCEPTION 'Saved quotation revisions are immutable.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.quotations revision
    WHERE revision.base_quotation_id = OLD.id
  ) THEN
    RAISE EXCEPTION 'An original quotation with revisions is immutable.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_quotation_revision_history
  ON public.quotations;

CREATE TRIGGER protect_quotation_revision_history
BEFORE UPDATE ON public.quotations
FOR EACH ROW
EXECUTE FUNCTION public.protect_quotation_revision_history();

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
  v_source_revision_no integer;
  v_source_salesperson text;
  v_base_id uuid;
  v_base_number text;
  v_base_salesperson text;
  v_latest_id uuid;
  v_latest_revision_no integer;
  v_next_revision_no integer;
  v_new_id uuid := gen_random_uuid();
  v_item jsonb;
  v_position integer := 0;
BEGIN
  SELECT
    quotation.base_quotation_id,
    quotation.quotation_number,
    quotation.revision_no,
    quotation.salesperson_id
  INTO
    v_source_base_id,
    v_source_number,
    v_source_revision_no,
    v_source_salesperson
  FROM public.quotations quotation
  WHERE quotation.id = p_source_quotation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source quotation was not found or is not accessible.';
  END IF;

  IF NOT v_is_admin AND v_source_salesperson <> v_current_user THEN
    RAISE EXCEPTION 'Unauthorized: Cannot revise quotations belonging to other salespersons.';
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

  SELECT quotation.id, quotation.revision_no
  INTO v_latest_id, v_latest_revision_no
  FROM public.quotations quotation
  WHERE quotation.id = v_base_id
     OR quotation.base_quotation_id = v_base_id
  ORDER BY quotation.revision_no DESC
  LIMIT 1;

  IF v_latest_id IS DISTINCT FROM p_source_quotation_id THEN
    RAISE EXCEPTION
      'Stale quotation revision source. Reload the latest quotation before revising.';
  END IF;

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

REVOKE ALL ON FUNCTION public.create_quotation_revision(uuid, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_quotation_revision(uuid, jsonb)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.create_quotation_revision(uuid, jsonb)
  TO authenticated;
