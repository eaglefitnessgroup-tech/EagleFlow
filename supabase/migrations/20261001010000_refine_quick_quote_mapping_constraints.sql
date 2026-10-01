ALTER TABLE public.quick_quote_product_mappings
  ALTER COLUMN section DROP NOT NULL;

ALTER TABLE public.quick_quote_product_mappings
  ADD CONSTRAINT quick_quote_product_mappings_status_section_check
    CHECK (
      status = 'manual_excluded'
      OR (status = 'eligible' AND section IS NOT NULL)
    ),
  ADD CONSTRAINT quick_quote_product_mappings_eligible_role_key_check
    CHECK (
      status = 'manual_excluded'
      OR role_key IS NOT NULL
    );
