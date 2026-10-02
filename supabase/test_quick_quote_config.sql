\set ON_ERROR_STOP on

-- Disposable-local validation for the versioned Quick Quote configuration.
-- Run only after 20261002000000_create_quick_quote_config_versions.sql.

RESET ROLE;
TRUNCATE public.quick_quote_config_versions CASCADE;
DELETE FROM public.app_users
WHERE id IN ('QQ-DB-ADMIN', 'QQ-DB-USER');
DELETE FROM public.products
WHERE id IN (
  '00000000-0000-0000-0000-000000000101'::uuid,
  '00000000-0000-0000-0000-000000000102'::uuid
);

INSERT INTO public.app_users (
  id, name, username, email, password_hash, role, is_active, supabase_uid
) VALUES
  (
    'QQ-DB-ADMIN', 'Quick Quote DB Admin', 'qq_db_admin',
    'qq-db-admin@example.invalid', '', 'admin', true,
    '10000000-0000-0000-0000-000000000001'
  ),
  (
    'QQ-DB-USER', 'Quick Quote DB User', 'qq_db_user',
    'qq-db-user@example.invalid', '', 'salesperson', true,
    '10000000-0000-0000-0000-000000000002'
  );

INSERT INTO public.products (
  id, product_code, normalized_product_code, name, category, brand,
  selling_price, is_vat_applicable, is_active
) VALUES
  (
    '00000000-0000-0000-0000-000000000101',
    'DB-P1', 'DB-P1', 'DB Product 1', 'Strength', 'Premier', 1000, true, true
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    'DB-P2', 'DB-P2', 'DB Product 2', 'Strength', 'Premier', 1200, true, true
  );

CREATE OR REPLACE FUNCTION pg_temp.assert_true(
  condition boolean,
  message text
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', message;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.quick_quote_payload(
  product_id uuid,
  duplicate_allocation boolean DEFAULT false
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_build_object(
    'profiles', jsonb_build_array(
      jsonb_build_object(
        'profile_id', 'DB-PROFILE',
        'brand', 'Premier',
        'budget_range', '1K-2K',
        'budget_min', 1000,
        'budget_max', 2000
      )
    ),
    'allocations',
      jsonb_build_array(
        jsonb_build_object(
          'profile_id', 'DB-PROFILE',
          'section_order', 1,
          'section', 'Strength',
          'equipment_role', 'Chest',
          'role_key', 'strength_chest',
          'product_code', 'DB-P1',
          'product_id', product_id,
          'quantity', 1,
          'selection_mode', 'Priority',
          'priority', 1,
          'review_flag', false,
          'notes', ''
        )
      ) ||
      CASE WHEN duplicate_allocation THEN
        jsonb_build_array(
          jsonb_build_object(
            'profile_id', 'DB-PROFILE',
            'section_order', 1,
            'section', 'Strength',
            'equipment_role', 'Chest duplicate',
            'role_key', 'strength_chest',
            'product_code', 'DB-P1',
            'product_id', product_id,
            'quantity', 1,
            'selection_mode', 'Priority',
            'priority', 1,
            'review_flag', false,
            'notes', 'Expected unique violation'
          )
        )
      ELSE '[]'::jsonb END,
    'strength_priorities', jsonb_build_array(
      jsonb_build_object(
        'brand', 'Premier',
        'strength_area', 'Chest',
        'priority', 1,
        'product_code', 'DB-P1',
        'product_id', product_id,
        'series_prefix', 'DB',
        'load_type', 'Pin Loaded',
        'equipment_role', 'Chest',
        'automation_rule', 'Use priority order',
        'source', 'Disposable local test'
      )
    ),
    'role_mappings', jsonb_build_array(
      jsonb_build_object(
        'product_code', 'DB-P1',
        'product_id', product_id,
        'product_name', 'DB Product 1',
        'catalog_brand', 'Premier',
        'category', 'Strength',
        'automation_section', 'Strength',
        'automation_role', 'Chest',
        'role_key', 'strength_chest',
        'unit_price_aed', 1000,
        'auto_eligible', 'Yes',
        'notes', ''
      )
    ),
    'rules', jsonb_build_array(
      jsonb_build_object(
        'rule', 'Disposable database test',
        'premier', 'Enabled',
        'burnsport', '',
        'automation_note', 'RPC validation fixture'
      )
    )
  );
$$;

-- Admin applies two complete versions through the intended RPC.
SET ROLE authenticated;
SET request.jwt.claims TO
  '{"sub":"10000000-0000-0000-0000-000000000001"}';

SELECT pg_temp.assert_true(public.is_admin(), 'admin identity was not recognized');

SELECT public.apply_quick_quote_config(
  'db-version-1.xlsx',
  '{"profiles":1,"allocations":1,"strength_priorities":1,"role_mappings":1,"warnings":0,"errors":0}',
  pg_temp.quick_quote_payload(
    '00000000-0000-0000-0000-000000000101'::uuid
  )
);

SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_versions),
  'first apply did not create exactly one version'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_versions WHERE is_active),
  'first apply did not activate exactly one version'
);

SELECT public.apply_quick_quote_config(
  'db-version-2.xlsx',
  '{"profiles":1,"allocations":1,"strength_priorities":1,"role_mappings":1,"warnings":0,"errors":0}',
  pg_temp.quick_quote_payload(
    '00000000-0000-0000-0000-000000000101'::uuid
  )
);

SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_versions),
  'second apply did not preserve version history'
);
SELECT pg_temp.assert_true(
  (
    SELECT count(*) = 1
      AND bool_and(source_filename = 'db-version-2.xlsx')
    FROM public.quick_quote_config_versions
    WHERE is_active
  ),
  'second apply did not atomically replace the active version'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_budget_profiles),
  'profile child rows were not inserted for both versions'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_allocations),
  'allocation child rows were not inserted for both versions'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_strength_priorities),
  'strength child rows were not inserted for both versions'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_role_mappings),
  'role-map child rows were not inserted for both versions'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_rules),
  'rule child rows were not inserted for both versions'
);

-- A child-row unique violation must roll back the entire third apply.
DO $$
DECLARE
  version_count_before bigint;
  active_id_before uuid;
BEGIN
  SELECT count(*) INTO version_count_before
  FROM public.quick_quote_config_versions;
  SELECT id INTO active_id_before
  FROM public.quick_quote_config_versions
  WHERE is_active;

  BEGIN
    PERFORM public.apply_quick_quote_config(
      'db-version-failed.xlsx',
      '{"profiles":1,"allocations":2,"strength_priorities":1,"role_mappings":1,"warnings":0,"errors":0}',
      pg_temp.quick_quote_payload(
        '00000000-0000-0000-0000-000000000101'::uuid,
        true
      )
    );
    RAISE EXCEPTION 'failed apply unexpectedly succeeded' USING ERRCODE = 'ZX001';
  EXCEPTION
    WHEN unique_violation THEN NULL;
  END;

  PERFORM pg_temp.assert_true(
    (SELECT count(*) = version_count_before FROM public.quick_quote_config_versions),
    'failed apply left a partial version'
  );
  PERFORM pg_temp.assert_true(
    (SELECT id = active_id_before FROM public.quick_quote_config_versions WHERE is_active),
    'failed apply changed the active version'
  );
END;
$$;

-- Reactivate the older immutable version; the newer version remains stored.
SELECT public.activate_quick_quote_config_version(
  (SELECT id FROM public.quick_quote_config_versions
   WHERE source_filename = 'db-version-1.xlsx')
);
SELECT pg_temp.assert_true(
  (
    SELECT count(*) = 1
      AND bool_and(source_filename = 'db-version-1.xlsx')
    FROM public.quick_quote_config_versions
    WHERE is_active
  ),
  'rollback did not activate the selected older version'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_versions),
  'rollback deleted version history'
);

-- Admin sees all versions and all configuration rows.
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_versions),
  'admin cannot read full version history'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_budget_profiles),
  'admin cannot read all profile rows'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_allocations),
  'admin cannot read all allocation rows'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_strength_priorities),
  'admin cannot read all strength rows'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_role_mappings),
  'admin cannot read all role-map rows'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 2 FROM public.quick_quote_config_rules),
  'admin cannot read all rule rows'
);

-- Even admins cannot bypass the RPC with direct table writes.
DO $$
BEGIN
  BEGIN
    UPDATE public.quick_quote_config_versions
    SET is_active = false
    WHERE is_active;
    RAISE EXCEPTION 'admin direct update unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

RESET ROLE;

-- Normal authenticated users see only the active runtime configuration.
SET ROLE authenticated;
SET request.jwt.claims TO
  '{"sub":"10000000-0000-0000-0000-000000000002"}';

SELECT pg_temp.assert_true(NOT public.is_admin(), 'normal user became admin');
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_versions),
  'normal user did not receive exactly one active version'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_budget_profiles),
  'normal user did not receive active profile rows only'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_allocations),
  'normal user did not receive active allocation rows only'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_strength_priorities),
  'normal user did not receive active strength rows only'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_role_mappings),
  'normal user did not receive active role-map rows only'
);
SELECT pg_temp.assert_true(
  (SELECT count(*) = 1 FROM public.quick_quote_config_rules),
  'normal user did not receive active rule rows only'
);

-- No direct INSERT/UPDATE/DELETE is available on any configuration table.
DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'quick_quote_config_versions',
    'quick_quote_budget_profiles',
    'quick_quote_config_allocations',
    'quick_quote_config_strength_priorities',
    'quick_quote_config_role_mappings',
    'quick_quote_config_rules'
  ] LOOP
    BEGIN
      EXECUTE format('INSERT INTO public.%I DEFAULT VALUES', table_name);
      RAISE EXCEPTION 'normal user INSERT unexpectedly succeeded on %', table_name
        USING ERRCODE = 'ZX001';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
      EXECUTE format('UPDATE public.%I SET sort_order = sort_order', table_name);
      RAISE EXCEPTION 'normal user UPDATE unexpectedly succeeded on %', table_name
        USING ERRCODE = 'ZX001';
    EXCEPTION
      WHEN undefined_column THEN
        BEGIN
          EXECUTE format('UPDATE public.%I SET is_active = is_active', table_name);
          RAISE EXCEPTION 'normal user UPDATE unexpectedly succeeded on %', table_name
            USING ERRCODE = 'ZX001';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
      WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
      EXECUTE format('DELETE FROM public.%I', table_name);
      RAISE EXCEPTION 'normal user DELETE unexpectedly succeeded on %', table_name
        USING ERRCODE = 'ZX001';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
END;
$$;

DO $$
BEGIN
  BEGIN
    PERFORM public.apply_quick_quote_config(
      'normal-user.xlsx',
      '{"errors":0}',
      pg_temp.quick_quote_payload(
        '00000000-0000-0000-0000-000000000101'::uuid
      )
    );
    RAISE EXCEPTION 'normal user apply RPC unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN
    PERFORM pg_temp.assert_true(
      SQLERRM = 'Admin access required',
      'normal apply failed for an unexpected reason'
    );
  END;

  BEGIN
    PERFORM public.activate_quick_quote_config_version(
      (SELECT id FROM public.quick_quote_config_versions LIMIT 1)
    );
    RAISE EXCEPTION 'normal user activate RPC unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN
    PERFORM pg_temp.assert_true(
      SQLERRM = 'Admin access required',
      'normal activate failed for an unexpected reason'
    );
  END;
END;
$$;

RESET ROLE;

-- Anonymous users have neither table reads nor RPC execution.
SET ROLE anon;
DO $$
BEGIN
  BEGIN
    PERFORM count(*) FROM public.quick_quote_config_versions;
    RAISE EXCEPTION 'anonymous version read unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.apply_quick_quote_config(
      'anonymous.xlsx', '{}', '{}'::jsonb
    );
    RAISE EXCEPTION 'anonymous apply RPC unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.activate_quick_quote_config_version(
      '00000000-0000-0000-0000-000000000000'::uuid
    );
    RAISE EXCEPTION 'anonymous activate RPC unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

RESET ROLE;

-- Owner-level direct mutation is blocked by immutable-content triggers.
DO $$
BEGIN
  BEGIN
    UPDATE public.quick_quote_config_versions
    SET source_filename = source_filename || '.tampered'
    WHERE source_filename = 'db-version-1.xlsx';
    RAISE EXCEPTION 'version metadata mutation unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN
    PERFORM pg_temp.assert_true(
      SQLERRM = 'Quick Quote configuration versions are immutable',
      'version metadata trigger returned an unexpected error'
    );
  END;

  BEGIN
    UPDATE public.quick_quote_budget_profiles
    SET budget_range = budget_range || '-tampered'
    WHERE id = (SELECT min(id) FROM public.quick_quote_budget_profiles);
    RAISE EXCEPTION 'profile mutation unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    UPDATE public.quick_quote_config_allocations
    SET notes = notes || 'tampered'
    WHERE id = (SELECT min(id) FROM public.quick_quote_config_allocations);
    RAISE EXCEPTION 'allocation mutation unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    UPDATE public.quick_quote_config_strength_priorities
    SET source = source || 'tampered'
    WHERE id = (SELECT min(id) FROM public.quick_quote_config_strength_priorities);
    RAISE EXCEPTION 'strength mutation unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    UPDATE public.quick_quote_config_role_mappings
    SET notes = notes || 'tampered'
    WHERE id = (SELECT min(id) FROM public.quick_quote_config_role_mappings);
    RAISE EXCEPTION 'role-map mutation unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    UPDATE public.quick_quote_config_rules
    SET automation_note = automation_note || 'tampered'
    WHERE id = (SELECT min(id) FROM public.quick_quote_config_rules);
    RAISE EXCEPTION 'rule mutation unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    DELETE FROM public.quick_quote_config_rules
    WHERE id = (SELECT min(id) FROM public.quick_quote_config_rules);
    RAISE EXCEPTION 'immutable child delete unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
END;
$$;

-- The partial unique index independently prevents two active versions.
DO $$
BEGIN
  BEGIN
    INSERT INTO public.quick_quote_config_versions (
      version_number, source_filename, created_by,
      activated_at, activated_by, is_active, validation_summary
    ) VALUES (
      999, 'direct-active-insert.xlsx', 'QQ-DB-ADMIN',
      now(), 'QQ-DB-ADMIN', true, '{"errors":0}'
    );
    RAISE EXCEPTION 'second active version insert unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.quick_quote_config_versions
    SET is_active = true
    WHERE source_filename = 'db-version-2.xlsx';
    RAISE EXCEPTION 'second active version update unexpectedly succeeded'
      USING ERRCODE = 'ZX001';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  PERFORM pg_temp.assert_true(
    (SELECT count(*) = 1 FROM public.quick_quote_config_versions WHERE is_active),
    'database contains more than one active version'
  );
END;
$$;

SELECT
  'quick_quote_config_database_validation_passed' AS result,
  count(*) AS stored_versions,
  count(*) FILTER (WHERE is_active) AS active_versions
FROM public.quick_quote_config_versions;
