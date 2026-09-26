ALTER TABLE public.quotation_items
  ADD COLUMN condition text NULL,
  ADD CONSTRAINT quotation_items_condition_check
    CHECK (
      condition IS NULL
      OR condition IN ('new', 'used', 'refurbished', 'display')
    );

CREATE OR REPLACE FUNCTION public.save_quotation(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = ''
AS $$
declare
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
begin
  v_target_salesperson := coalesce(p_payload->>'salespersonId', '');

  v_created_at := coalesce(
    nullif(p_payload->>'createdDate', '')::timestamptz,
    now()
  );

  if nullif(p_payload->>'id', '') is null then
    v_id := gen_random_uuid();
    -- It's a CREATE
    if not v_is_admin then
       if v_target_salesperson != v_current_user then
          raise exception 'Unauthorized: Cannot create quotations for other salespersons.';
       end if;
       v_target_salesperson := v_current_user;
    end if;

    v_number := nullif(p_payload->>'quotationNumber', '');
    if v_number is null or v_number like 'DRAFT-%' then
      v_number := public.allocate_quotation_number(v_target_salesperson, extract(year from (v_created_at at time zone 'UTC'))::integer);
    end if;
  else
    v_id := (p_payload->>'id')::uuid;
    -- It's an UPDATE
    select salesperson_id, quotation_number into v_existing_salesperson, v_existing_number from public.quotations where id = v_id;
    if not v_is_admin then
       if v_existing_salesperson is not null and v_existing_salesperson != v_current_user then
          raise exception 'Unauthorized: Cannot modify quotations belonging to other salespersons.';
       end if;
       if v_target_salesperson != v_current_user then
          raise exception 'Unauthorized: Cannot reassign quotations to other salespersons.';
       end if;
       v_target_salesperson := v_current_user;
    end if;

    -- Ensure quotation number immutability
    if v_existing_number is not null and v_existing_number not like 'DRAFT-%' then
      v_number := v_existing_number;
    else
      v_number := nullif(p_payload->>'quotationNumber', '');
      if v_number is null or v_number like 'DRAFT-%' then
        v_number := public.allocate_quotation_number(v_target_salesperson, extract(year from (v_created_at at time zone 'UTC'))::integer);
      end if;
    end if;
  end if;

  insert into public.quotations (
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
  values (
    v_id,
    v_number,
    v_target_salesperson,
    coalesce(p_payload #>> '{customerInfo,name}', ''),
    coalesce(p_payload #>> '{customerInfo,company}', ''),
    coalesce(p_payload #>> '{customerInfo,phone}', ''),
    coalesce(p_payload #>> '{customerInfo,email}', ''),
    coalesce(p_payload #>> '{customerInfo,projectLocation}', ''),
    coalesce(nullif(p_payload #>> '{charges,deliveryCharges}', '')::numeric, 0),
    coalesce(nullif(p_payload #>> '{charges,installationCharges}', '')::numeric, 0),
    coalesce(nullif(p_payload #>> '{charges,otherCharges}', '')::numeric, 0),
    coalesce(nullif(p_payload #>> '{charges,overallDiscount}', '')::numeric, 0),
    coalesce(nullif(p_payload #>> '{charges,vatPercentage}', '')::numeric, 5),
    coalesce(p_payload->>'customerNotes', ''),
    coalesce(p_payload->>'internalNotes', ''),
    coalesce(p_payload->>'status', 'draft'),
    coalesce((p_payload->>'isStockOutProcessed')::boolean, false),
    coalesce(nullif(p_payload->>'validUntil', '')::timestamptz, now()),
    nullif(p_payload->>'expectedDelivery', '')::timestamptz,
    v_created_at,
    coalesce(nullif(p_payload->>'modifiedDate', '')::timestamptz, now())
  )
  on conflict (id) do update set
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

  delete from public.quotation_items where quotation_id = v_id;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(coalesce(p_payload->'lineItems', '[]'::jsonb))
  loop
    insert into public.quotation_items (
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
    values (
      coalesce(nullif(v_item->>'id', '')::uuid, gen_random_uuid()),
      v_id,
      nullif(v_item->>'productId', '')::uuid,
      nullif(v_item->>'productCode', ''),
      coalesce(v_item->>'name', ''),
      coalesce(v_item->>'brand', ''),
      nullif(v_item->>'condition', ''),
      coalesce(nullif(v_item->>'unitPrice', '')::numeric, 0),
      greatest(coalesce(nullif(v_item->>'quantity', '')::integer, 1), 1),
      coalesce(nullif(v_item->>'discount', '')::numeric, 0),
      nullif(v_item->>'description', ''),
      coalesce((v_item->>'isCustom')::boolean, false),
      coalesce((v_item->>'isVatApplicable')::boolean, true),
      nullif(v_item->>'imagePath', ''),
      nullif(v_item->>'imageId', ''),
      v_position
    );
    v_position := v_position + 1;
  end loop;

  return pg_catalog.jsonb_build_object(
    'id', v_id::text,
    'quotationNumber', v_number
  );
exception
  when others then
    return pg_catalog.jsonb_build_object('error', sqlerrm);
end;
$$;

REVOKE ALL ON FUNCTION public.save_quotation(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_quotation(jsonb) FROM anon;

GRANT EXECUTE ON FUNCTION public.save_quotation(jsonb) TO authenticated;
