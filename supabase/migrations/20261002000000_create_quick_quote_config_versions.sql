-- Versioned, immutable Quick Quote automation configuration foundation.
-- This migration is additive and does not switch the existing optimizer.

CREATE TABLE public.quick_quote_config_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_number bigint NOT NULL UNIQUE,
  source_filename text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text NOT NULL REFERENCES public.app_users(id),
  activated_at timestamptz,
  activated_by text REFERENCES public.app_users(id),
  is_active boolean NOT NULL DEFAULT false,
  validation_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT quick_quote_config_versions_filename_check
    CHECK (length(btrim(source_filename)) > 0),
  CONSTRAINT quick_quote_config_versions_activation_check
    CHECK (
      (is_active = false)
      OR (activated_at IS NOT NULL AND activated_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX quick_quote_config_versions_single_active_idx
  ON public.quick_quote_config_versions (is_active)
  WHERE is_active = true;

CREATE TABLE public.quick_quote_budget_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  config_version_id uuid NOT NULL
    REFERENCES public.quick_quote_config_versions(id) ON DELETE RESTRICT,
  sort_order integer NOT NULL,
  profile_id text NOT NULL,
  brand text NOT NULL,
  budget_range text NOT NULL,
  budget_min numeric(14,2) NOT NULL,
  budget_max numeric(14,2) NOT NULL,
  UNIQUE (config_version_id, profile_id),
  CONSTRAINT quick_quote_budget_profiles_budget_check
    CHECK (budget_min >= 0 AND budget_max >= budget_min)
);

CREATE TABLE public.quick_quote_config_allocations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  config_version_id uuid NOT NULL
    REFERENCES public.quick_quote_config_versions(id) ON DELETE RESTRICT,
  sort_order integer NOT NULL,
  profile_id text NOT NULL,
  section_order integer NOT NULL,
  section text NOT NULL,
  equipment_role text NOT NULL,
  role_key text NOT NULL,
  product_code text NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity integer NOT NULL,
  selection_mode text NOT NULL,
  priority integer NOT NULL,
  review_flag boolean NOT NULL DEFAULT false,
  notes text NOT NULL DEFAULT '',
  FOREIGN KEY (config_version_id, profile_id)
    REFERENCES public.quick_quote_budget_profiles(config_version_id, profile_id)
    ON DELETE RESTRICT,
  UNIQUE (config_version_id, profile_id, role_key, priority),
  CONSTRAINT quick_quote_config_allocations_quantity_check CHECK (quantity > 0),
  CONSTRAINT quick_quote_config_allocations_order_check
    CHECK (section_order > 0 AND priority > 0)
);

CREATE TABLE public.quick_quote_config_strength_priorities (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  config_version_id uuid NOT NULL
    REFERENCES public.quick_quote_config_versions(id) ON DELETE RESTRICT,
  sort_order integer NOT NULL,
  brand text NOT NULL,
  strength_area text NOT NULL,
  priority integer NOT NULL,
  product_code text NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  series_prefix text NOT NULL,
  load_type text NOT NULL,
  equipment_role text NOT NULL,
  automation_rule text NOT NULL DEFAULT '',
  source text NOT NULL DEFAULT '',
  UNIQUE (
    config_version_id,
    brand,
    strength_area,
    load_type,
    priority
  ),
  CONSTRAINT quick_quote_config_strength_priority_check CHECK (priority > 0)
);

CREATE TABLE public.quick_quote_config_role_mappings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  config_version_id uuid NOT NULL
    REFERENCES public.quick_quote_config_versions(id) ON DELETE RESTRICT,
  sort_order integer NOT NULL,
  product_code text NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  product_name text NOT NULL,
  catalog_brand text NOT NULL,
  category text NOT NULL,
  automation_section text NOT NULL,
  automation_role text NOT NULL,
  role_key text NOT NULL,
  unit_price_aed numeric(14,2) NOT NULL,
  auto_eligible text NOT NULL,
  notes text NOT NULL DEFAULT '',
  UNIQUE (config_version_id, product_code, role_key),
  CONSTRAINT quick_quote_config_role_price_check CHECK (unit_price_aed > 0),
  CONSTRAINT quick_quote_config_role_eligible_check
    CHECK (auto_eligible IN ('Yes', 'No', 'Review'))
);

CREATE TABLE public.quick_quote_config_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  config_version_id uuid NOT NULL
    REFERENCES public.quick_quote_config_versions(id) ON DELETE RESTRICT,
  sort_order integer NOT NULL,
  rule text NOT NULL,
  premier text NOT NULL DEFAULT '',
  burnsport text NOT NULL DEFAULT '',
  automation_note text NOT NULL DEFAULT '',
  UNIQUE (config_version_id, rule)
);

CREATE OR REPLACE FUNCTION public.protect_quick_quote_config_version()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.id IS DISTINCT FROM NEW.id
     OR OLD.version_number IS DISTINCT FROM NEW.version_number
     OR OLD.source_filename IS DISTINCT FROM NEW.source_filename
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.validation_summary IS DISTINCT FROM NEW.validation_summary THEN
    RAISE EXCEPTION 'Quick Quote configuration versions are immutable';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER protect_quick_quote_config_version_update
BEFORE UPDATE ON public.quick_quote_config_versions
FOR EACH ROW EXECUTE FUNCTION public.protect_quick_quote_config_version();

CREATE OR REPLACE FUNCTION public.reject_quick_quote_config_child_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'Quick Quote configuration rows are immutable';
END;
$$;

CREATE TRIGGER protect_quick_quote_budget_profiles
BEFORE UPDATE OR DELETE ON public.quick_quote_budget_profiles
FOR EACH ROW EXECUTE FUNCTION public.reject_quick_quote_config_child_mutation();
CREATE TRIGGER protect_quick_quote_config_allocations
BEFORE UPDATE OR DELETE ON public.quick_quote_config_allocations
FOR EACH ROW EXECUTE FUNCTION public.reject_quick_quote_config_child_mutation();
CREATE TRIGGER protect_quick_quote_config_strength_priorities
BEFORE UPDATE OR DELETE ON public.quick_quote_config_strength_priorities
FOR EACH ROW EXECUTE FUNCTION public.reject_quick_quote_config_child_mutation();
CREATE TRIGGER protect_quick_quote_config_role_mappings
BEFORE UPDATE OR DELETE ON public.quick_quote_config_role_mappings
FOR EACH ROW EXECUTE FUNCTION public.reject_quick_quote_config_child_mutation();
CREATE TRIGGER protect_quick_quote_config_rules
BEFORE UPDATE OR DELETE ON public.quick_quote_config_rules
FOR EACH ROW EXECUTE FUNCTION public.reject_quick_quote_config_child_mutation();

CREATE OR REPLACE FUNCTION public.apply_quick_quote_config(
  p_source_filename text,
  p_validation_summary jsonb,
  p_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id text;
  v_version_id uuid;
  v_version_number bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Active application user mapping required';
  END IF;
  IF p_source_filename IS NULL OR btrim(p_source_filename) = '' THEN
    RAISE EXCEPTION 'Source filename is required';
  END IF;
  IF COALESCE((p_validation_summary->>'errors')::integer, 1) <> 0 THEN
    RAISE EXCEPTION 'Configuration contains validation errors';
  END IF;
  IF jsonb_typeof(p_payload->'profiles') <> 'array'
     OR jsonb_array_length(p_payload->'profiles') = 0
     OR jsonb_typeof(p_payload->'allocations') <> 'array'
     OR jsonb_typeof(p_payload->'strength_priorities') <> 'array'
     OR jsonb_typeof(p_payload->'role_mappings') <> 'array'
     OR jsonb_typeof(p_payload->'rules') <> 'array' THEN
    RAISE EXCEPTION 'Complete normalized configuration payload is required';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT value FROM jsonb_array_elements(p_payload->'allocations')
      UNION ALL
      SELECT value FROM jsonb_array_elements(p_payload->'strength_priorities')
      UNION ALL
      SELECT value FROM jsonb_array_elements(p_payload->'role_mappings')
    ) config_row
    LEFT JOIN public.products product
      ON product.id = (config_row.value->>'product_id')::uuid
      AND product.normalized_product_code = config_row.value->>'product_code'
    WHERE product.id IS NULL
       OR product.is_active IS NOT TRUE
       OR product.deleted_at IS NOT NULL
       OR product.selling_price <= 0
  ) THEN
    RAISE EXCEPTION 'All product references must resolve to active, non-deleted products with positive prices';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('quick_quote_config_version')
  );
  SELECT COALESCE(MAX(version_number), 0) + 1
  INTO v_version_number
  FROM public.quick_quote_config_versions;

  INSERT INTO public.quick_quote_config_versions (
    version_number,
    source_filename,
    created_by,
    validation_summary
  ) VALUES (
    v_version_number,
    p_source_filename,
    v_user_id,
    p_validation_summary
  ) RETURNING id INTO v_version_id;

  INSERT INTO public.quick_quote_budget_profiles (
    config_version_id, sort_order, profile_id, brand, budget_range,
    budget_min, budget_max
  )
  SELECT
    v_version_id,
    entry.ordinality::integer,
    entry.value->>'profile_id',
    entry.value->>'brand',
    entry.value->>'budget_range',
    (entry.value->>'budget_min')::numeric,
    (entry.value->>'budget_max')::numeric
  FROM jsonb_array_elements(p_payload->'profiles') WITH ORDINALITY AS entry(value, ordinality);

  INSERT INTO public.quick_quote_config_allocations (
    config_version_id, sort_order, profile_id, section_order, section,
    equipment_role, role_key, product_code, product_id, quantity,
    selection_mode, priority, review_flag, notes
  )
  SELECT
    v_version_id,
    entry.ordinality::integer,
    entry.value->>'profile_id',
    (entry.value->>'section_order')::integer,
    entry.value->>'section',
    entry.value->>'equipment_role',
    entry.value->>'role_key',
    entry.value->>'product_code',
    (entry.value->>'product_id')::uuid,
    (entry.value->>'quantity')::integer,
    entry.value->>'selection_mode',
    (entry.value->>'priority')::integer,
    (entry.value->>'review_flag')::boolean,
    COALESCE(entry.value->>'notes', '')
  FROM jsonb_array_elements(p_payload->'allocations') WITH ORDINALITY AS entry(value, ordinality);

  INSERT INTO public.quick_quote_config_strength_priorities (
    config_version_id, sort_order, brand, strength_area, priority,
    product_code, product_id, series_prefix, load_type, equipment_role,
    automation_rule, source
  )
  SELECT
    v_version_id,
    entry.ordinality::integer,
    entry.value->>'brand',
    entry.value->>'strength_area',
    (entry.value->>'priority')::integer,
    entry.value->>'product_code',
    (entry.value->>'product_id')::uuid,
    entry.value->>'series_prefix',
    entry.value->>'load_type',
    entry.value->>'equipment_role',
    COALESCE(entry.value->>'automation_rule', ''),
    COALESCE(entry.value->>'source', '')
  FROM jsonb_array_elements(p_payload->'strength_priorities') WITH ORDINALITY AS entry(value, ordinality);

  INSERT INTO public.quick_quote_config_role_mappings (
    config_version_id, sort_order, product_code, product_id, product_name,
    catalog_brand, category, automation_section, automation_role, role_key,
    unit_price_aed, auto_eligible, notes
  )
  SELECT
    v_version_id,
    entry.ordinality::integer,
    entry.value->>'product_code',
    (entry.value->>'product_id')::uuid,
    entry.value->>'product_name',
    entry.value->>'catalog_brand',
    entry.value->>'category',
    entry.value->>'automation_section',
    entry.value->>'automation_role',
    entry.value->>'role_key',
    (entry.value->>'unit_price_aed')::numeric,
    entry.value->>'auto_eligible',
    COALESCE(entry.value->>'notes', '')
  FROM jsonb_array_elements(p_payload->'role_mappings') WITH ORDINALITY AS entry(value, ordinality);

  INSERT INTO public.quick_quote_config_rules (
    config_version_id, sort_order, rule, premier, burnsport, automation_note
  )
  SELECT
    v_version_id,
    entry.ordinality::integer,
    entry.value->>'rule',
    COALESCE(entry.value->>'premier', ''),
    COALESCE(entry.value->>'burnsport', ''),
    COALESCE(entry.value->>'automation_note', '')
  FROM jsonb_array_elements(p_payload->'rules') WITH ORDINALITY AS entry(value, ordinality);

  UPDATE public.quick_quote_config_versions
  SET is_active = false
  WHERE is_active = true;

  UPDATE public.quick_quote_config_versions
  SET
    is_active = true,
    activated_at = now(),
    activated_by = v_user_id
  WHERE id = v_version_id;

  RETURN v_version_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.activate_quick_quote_config_version(
  p_version_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;
  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Active application user mapping required';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('quick_quote_config_version')
  );
  PERFORM 1
  FROM public.quick_quote_config_versions
  WHERE id = p_version_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Configuration version not found';
  END IF;

  UPDATE public.quick_quote_config_versions
  SET is_active = false
  WHERE is_active = true AND id <> p_version_id;

  UPDATE public.quick_quote_config_versions
  SET
    is_active = true,
    activated_at = now(),
    activated_by = v_user_id
  WHERE id = p_version_id;

  RETURN p_version_id;
END;
$$;

ALTER TABLE public.quick_quote_config_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_quote_budget_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_quote_config_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_quote_config_strength_priorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_quote_config_role_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_quote_config_rules ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.quick_quote_config_versions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.quick_quote_budget_profiles FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.quick_quote_config_allocations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.quick_quote_config_strength_priorities FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.quick_quote_config_role_mappings FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.quick_quote_config_rules FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.quick_quote_config_versions TO authenticated;
GRANT SELECT ON public.quick_quote_budget_profiles TO authenticated;
GRANT SELECT ON public.quick_quote_config_allocations TO authenticated;
GRANT SELECT ON public.quick_quote_config_strength_priorities TO authenticated;
GRANT SELECT ON public.quick_quote_config_role_mappings TO authenticated;
GRANT SELECT ON public.quick_quote_config_rules TO authenticated;

GRANT ALL ON public.quick_quote_config_versions TO service_role;
GRANT ALL ON public.quick_quote_budget_profiles TO service_role;
GRANT ALL ON public.quick_quote_config_allocations TO service_role;
GRANT ALL ON public.quick_quote_config_strength_priorities TO service_role;
GRANT ALL ON public.quick_quote_config_role_mappings TO service_role;
GRANT ALL ON public.quick_quote_config_rules TO service_role;

CREATE POLICY "Admins read all Quick Quote config versions"
  ON public.quick_quote_config_versions FOR SELECT TO authenticated
  USING (public.is_admin());
CREATE POLICY "Users read active Quick Quote config version"
  ON public.quick_quote_config_versions FOR SELECT TO authenticated
  USING (is_active = true);

CREATE POLICY "Users read active Quick Quote budget profiles"
  ON public.quick_quote_budget_profiles FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.quick_quote_config_versions version
      WHERE version.id = config_version_id AND version.is_active = true
    )
  );
CREATE POLICY "Users read active Quick Quote allocations"
  ON public.quick_quote_config_allocations FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.quick_quote_config_versions version
      WHERE version.id = config_version_id AND version.is_active = true
    )
  );
CREATE POLICY "Users read active Quick Quote strength priorities"
  ON public.quick_quote_config_strength_priorities FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.quick_quote_config_versions version
      WHERE version.id = config_version_id AND version.is_active = true
    )
  );
CREATE POLICY "Users read active Quick Quote role mappings"
  ON public.quick_quote_config_role_mappings FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.quick_quote_config_versions version
      WHERE version.id = config_version_id AND version.is_active = true
    )
  );
CREATE POLICY "Users read active Quick Quote rules"
  ON public.quick_quote_config_rules FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.quick_quote_config_versions version
      WHERE version.id = config_version_id AND version.is_active = true
    )
  );

REVOKE ALL ON FUNCTION public.apply_quick_quote_config(text, jsonb, jsonb)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.activate_quick_quote_config_version(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_quick_quote_config(text, jsonb, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.activate_quick_quote_config_version(uuid)
  TO authenticated;
