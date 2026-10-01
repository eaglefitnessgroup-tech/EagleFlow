CREATE TABLE public.quick_quote_product_mappings (
  product_id uuid PRIMARY KEY
    REFERENCES public.products(id)
    ON DELETE CASCADE,
  status text NOT NULL
    CONSTRAINT quick_quote_product_mappings_status_check
      CHECK (status IN ('eligible', 'manual_excluded')),
  section text NOT NULL
    CONSTRAINT quick_quote_product_mappings_section_check
      CHECK (
        section IN (
          'cardio',
          'strength',
          'multifunction',
          'dumbbell',
          'dumbbell_rack',
          'weight_plate'
        )
      ),
  role_key text,
  strength_area text
    CONSTRAINT quick_quote_product_mappings_strength_area_check
      CHECK (
        strength_area IS NULL
        OR strength_area IN (
          'chest',
          'back',
          'shoulder',
          'legs',
          'arms',
          'glutes',
          'core'
        )
      ),
  load_type text
    CONSTRAINT quick_quote_product_mappings_load_type_check
      CHECK (
        load_type IS NULL
        OR load_type IN ('pin_loaded', 'plate_loaded')
      ),
  movement_key text,
  family_key text,
  plate_weight_kg numeric,
  station_count integer,
  selection_priority integer NOT NULL DEFAULT 100,
  upgrade_priority integer NOT NULL DEFAULT 100,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT quick_quote_product_mappings_selection_priority_check
    CHECK (selection_priority >= 0),
  CONSTRAINT quick_quote_product_mappings_upgrade_priority_check
    CHECK (upgrade_priority >= 0),
  CONSTRAINT quick_quote_product_mappings_station_count_positive_check
    CHECK (station_count IS NULL OR station_count > 0),
  CONSTRAINT quick_quote_product_mappings_plate_weight_positive_check
    CHECK (plate_weight_kg IS NULL OR plate_weight_kg > 0),
  CONSTRAINT quick_quote_product_mappings_strength_area_section_check
    CHECK (strength_area IS NULL OR section = 'strength'),
  CONSTRAINT quick_quote_product_mappings_load_type_section_check
    CHECK (load_type IS NULL OR section = 'strength'),
  CONSTRAINT quick_quote_product_mappings_plate_weight_section_check
    CHECK (plate_weight_kg IS NULL OR section = 'weight_plate'),
  CONSTRAINT quick_quote_product_mappings_station_count_role_check
    CHECK (
      station_count IS NULL
      OR (section = 'multifunction' AND role_key = 'multi_station')
    )
);

CREATE INDEX quick_quote_product_mappings_status_idx
  ON public.quick_quote_product_mappings (status);

CREATE INDEX quick_quote_product_mappings_section_idx
  ON public.quick_quote_product_mappings (section);

CREATE INDEX quick_quote_product_mappings_role_key_idx
  ON public.quick_quote_product_mappings (role_key);

CREATE INDEX quick_quote_product_mappings_strength_area_idx
  ON public.quick_quote_product_mappings (strength_area);

CREATE INDEX quick_quote_product_mappings_load_type_idx
  ON public.quick_quote_product_mappings (load_type);

CREATE INDEX quick_quote_product_mappings_family_key_idx
  ON public.quick_quote_product_mappings (family_key);

REVOKE ALL ON public.quick_quote_product_mappings
  FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.quick_quote_product_mappings TO authenticated;
GRANT ALL ON public.quick_quote_product_mappings TO service_role;

ALTER TABLE public.quick_quote_product_mappings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read quick quote product mappings"
  ON public.quick_quote_product_mappings
  FOR SELECT
  TO authenticated
  USING (true);
