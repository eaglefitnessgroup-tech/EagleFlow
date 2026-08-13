-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

DROP EXTENSION pg_net;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;

CREATE FUNCTION public.get_current_stock (
  p_product_id uuid
)
  RETURNS integer
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
  select
    coalesce((select opening_stock from public.products where id = p_product_id), 0)
    + coalesce(sum(
        case
          when type = 'stockIn' then quantity
          when type = 'stockOut' then -quantity
          else 0
        end
      ), 0)::integer
  from public.stock_movements
  where product_id = p_product_id;
$function$;

GRANT ALL ON FUNCTION public.get_current_stock(uuid) TO anon;

GRANT ALL ON FUNCTION public.get_current_stock(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.get_current_stock(uuid) TO service_role;

CREATE FUNCTION public.save_quotation (
  p_payload jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
declare
  v_id uuid;
  v_number text;
  v_item jsonb;
  v_position integer := 0;
  v_created_at timestamptz;
begin
  if nullif(p_payload->>'id', '') is null then
    v_id := gen_random_uuid();
  else
    v_id := (p_payload->>'id')::uuid;
  end if;

  v_created_at := coalesce(
    nullif(p_payload->>'createdDate', '')::timestamptz,
    now()
  );

  v_number := nullif(p_payload->>'quotationNumber', '');
  if v_number is null or v_number like 'DRAFT-%' then
    v_number :=
      'EF-' ||
      to_char(v_created_at at time zone 'UTC', 'YYYYMMDD') ||
      '-' ||
      upper(substr(replace(v_id::text, '-', ''), 1, 8));
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
    coalesce(p_payload->>'salespersonId', ''),
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
    from jsonb_array_elements(coalesce(p_payload->'lineItems', '[]'::jsonb))
  loop
    insert into public.quotation_items (
      id,
      quotation_id,
      product_id,
      product_code,
      name,
      brand,
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

  return jsonb_build_object(
    'id', v_id::text,
    'quotationNumber', v_number
  );
exception
  when others then
    return jsonb_build_object('error', sqlerrm);
end;
$function$;

GRANT ALL ON FUNCTION public.save_quotation(jsonb) TO anon;

GRANT ALL ON FUNCTION public.save_quotation(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.save_quotation(jsonb) TO service_role;

CREATE TABLE public.app_users (
  id            text                     NOT NULL,
  name          text                     DEFAULT ''::text NOT NULL,
  username      text                     NOT NULL,
  password_hash text                     DEFAULT ''::text NOT NULL,
  role          text                     DEFAULT 'salesperson'::text NOT NULL,
  is_active     boolean                  DEFAULT true NOT NULL,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  email         text,
  supabase_uid  text
);

ALTER TABLE public.app_users
  ADD CONSTRAINT app_users_pkey PRIMARY KEY (id);

ALTER TABLE public.app_users
  ADD CONSTRAINT app_users_role_check CHECK (role = ANY (ARRAY['admin'::text, 'salesperson'::text]));

ALTER TABLE public.app_users
  ADD CONSTRAINT app_users_username_key UNIQUE (username);

GRANT ALL ON public.app_users TO anon;

GRANT ALL ON public.app_users TO authenticated;

GRANT ALL ON public.app_users TO service_role;

CREATE TABLE public.products (
  id                      uuid                     NOT NULL,
  product_code            text                     NOT NULL,
  normalized_product_code text                     NOT NULL,
  name                    text                     NOT NULL,
  category                text                     DEFAULT 'Uncategorized'::text NOT NULL,
  brand                   text                     DEFAULT 'Unknown'::text NOT NULL,
  description             text                     DEFAULT ''::text NOT NULL,
  model_number            text,
  unit                    text                     DEFAULT 'Nos'::text NOT NULL,
  selling_price           numeric(14,2)            DEFAULT 0 NOT NULL,
  is_vat_applicable       boolean                  DEFAULT true NOT NULL,
  is_active               boolean                  DEFAULT true NOT NULL,
  min_stock_level         integer                  DEFAULT 0 NOT NULL,
  opening_stock           integer                  DEFAULT 0 NOT NULL,
  notes                   text,
  image_id                text,
  created_at              timestamp with time zone DEFAULT now() NOT NULL,
  updated_at              timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at              timestamp with time zone
);

ALTER TABLE public.products
  ADD CONSTRAINT products_min_stock_level_check CHECK (min_stock_level >= 0);

ALTER TABLE public.products
  ADD CONSTRAINT products_opening_stock_check CHECK (opening_stock >= 0);

ALTER TABLE public.products
  ADD CONSTRAINT products_pkey PRIMARY KEY (id);

ALTER TABLE public.products
  ADD CONSTRAINT products_selling_price_check CHECK (selling_price >= 0::numeric);

GRANT ALL ON public.products TO anon;

GRANT ALL ON public.products TO authenticated;

GRANT ALL ON public.products TO service_role;

CREATE UNIQUE INDEX products_normalized_code_unique ON public.products (normalized_product_code)
  WHERE deleted_at IS NULL;

CREATE INDEX products_updated_at_idx ON public.products (updated_at DESC);

CREATE TABLE public.quotation_items (
  id                 uuid          NOT NULL,
  quotation_id       uuid          NOT NULL,
  product_id         uuid,
  product_code       text,
  name               text          NOT NULL,
  brand              text          DEFAULT ''::text NOT NULL,
  unit_price         numeric(14,2) DEFAULT 0 NOT NULL,
  quantity           integer       NOT NULL,
  discount           numeric(14,2) DEFAULT 0 NOT NULL,
  description        text,
  is_custom          boolean       DEFAULT false NOT NULL,
  is_vat_applicable  boolean       DEFAULT true NOT NULL,
  image_storage_path text,
  image_id           text,
  sort_order         integer       DEFAULT 0 NOT NULL
);

ALTER TABLE public.quotation_items
  ADD CONSTRAINT quotation_items_pkey PRIMARY KEY (id);

ALTER TABLE public.quotation_items
  ADD CONSTRAINT quotation_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;

ALTER TABLE public.quotation_items
  ADD CONSTRAINT quotation_items_quantity_check CHECK (quantity > 0);

GRANT ALL ON public.quotation_items TO anon;

GRANT ALL ON public.quotation_items TO authenticated;

GRANT ALL ON public.quotation_items TO service_role;

CREATE INDEX quotation_items_quotation_idx ON public.quotation_items (quotation_id, sort_order);

CREATE TABLE public.quotations (
  id                     uuid                     NOT NULL,
  quotation_number       text                     NOT NULL,
  salesperson_id         text                     NOT NULL,
  customer_name          text                     DEFAULT ''::text NOT NULL,
  customer_company       text                     DEFAULT ''::text NOT NULL,
  customer_phone         text                     DEFAULT ''::text NOT NULL,
  customer_email         text                     DEFAULT ''::text NOT NULL,
  project_location       text                     DEFAULT ''::text NOT NULL,
  delivery_charges       numeric(14,2)            DEFAULT 0 NOT NULL,
  installation_charges   numeric(14,2)            DEFAULT 0 NOT NULL,
  other_charges          numeric(14,2)            DEFAULT 0 NOT NULL,
  overall_discount       numeric(14,2)            DEFAULT 0 NOT NULL,
  vat_percentage         numeric(8,3)             DEFAULT 5 NOT NULL,
  customer_notes         text                     DEFAULT ''::text NOT NULL,
  internal_notes         text                     DEFAULT ''::text NOT NULL,
  status                 text                     DEFAULT 'draft'::text NOT NULL,
  is_stock_out_processed boolean                  DEFAULT false NOT NULL,
  valid_until            timestamp with time zone NOT NULL,
  expected_delivery      timestamp with time zone,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.quotations
  ADD CONSTRAINT quotations_pkey PRIMARY KEY (id);

ALTER TABLE public.quotation_items
  ADD CONSTRAINT quotation_items_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(id) ON DELETE CASCADE;

ALTER TABLE public.quotations
  ADD CONSTRAINT quotations_quotation_number_key UNIQUE (quotation_number);

GRANT ALL ON public.quotations TO anon;

GRANT ALL ON public.quotations TO authenticated;

GRANT ALL ON public.quotations TO service_role;

CREATE INDEX quotations_created_at_idx ON public.quotations (created_at DESC);

CREATE INDEX quotations_salesperson_idx ON public.quotations (salesperson_id);

CREATE TABLE public.reservations (
  id               text                     NOT NULL,
  product_id       text                     NOT NULL,
  product_name     text                     NOT NULL,
  product_code     text                     NOT NULL,
  quantity         integer                  NOT NULL,
  reference        text,
  reserved_by_id   text                     NOT NULL,
  reserved_by_name text                     NOT NULL,
  reserved_date    timestamp with time zone NOT NULL,
  expiry_date      timestamp with time zone NOT NULL,
  status           text                     NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

ALTER PUBLICATION supabase_realtime ADD TABLE public.reservations;

ALTER TABLE public.reservations
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.reservations
  ADD CONSTRAINT reservations_pkey PRIMARY KEY (id);

ALTER TABLE public.reservations
  ADD CONSTRAINT reservations_quantity_check CHECK (quantity > 0);

ALTER TABLE public.reservations
  ADD CONSTRAINT reservations_status_check CHECK (status = ANY (ARRAY['ACTIVE'::text, 'COMPLETED'::text, 'CANCELLED'::text, 'EXPIRED'::text]));

GRANT ALL ON public.reservations TO anon;

GRANT ALL ON public.reservations TO authenticated;

GRANT ALL ON public.reservations TO service_role;

CREATE INDEX idx_reservations_status ON public.reservations (status);

CREATE INDEX idx_reservations_product_id ON public.reservations (product_id);

CREATE INDEX idx_reservations_expiry_date ON public.reservations (expiry_date);

CREATE POLICY "Allow reservation delete" ON public.reservations
  FOR DELETE
  USING (true);

CREATE POLICY "Allow reservation insert" ON public.reservations
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow reservation read" ON public.reservations
  FOR SELECT
  USING (true);

CREATE POLICY "Allow reservation update" ON public.reservations
  FOR UPDATE
  USING (true);

CREATE TABLE public.stock_movements (
  id            uuid                     NOT NULL,
  product_id    uuid                     NOT NULL,
  type          text                     NOT NULL,
  quantity      integer                  NOT NULL,
  reference     text                     NOT NULL,
  movement_date timestamp with time zone DEFAULT now() NOT NULL,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  created_by    text                     DEFAULT 'system'::text NOT NULL
);

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_quantity_check CHECK (quantity > 0);

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_type_check CHECK (type = ANY (ARRAY['stockIn'::text, 'stockOut'::text]));

GRANT ALL ON public.stock_movements TO anon;

GRANT ALL ON public.stock_movements TO authenticated;

GRANT ALL ON public.stock_movements TO service_role;

CREATE INDEX stock_movements_product_idx ON public.stock_movements (product_id, movement_date DESC, created_at DESC);
