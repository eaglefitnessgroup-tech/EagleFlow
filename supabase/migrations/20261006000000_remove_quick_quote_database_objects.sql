-- Remove the retired Quick Quote / Quick Gym Automation database feature.
--
-- The historical Quick Quote migrations remain in the repository for migration
-- history.  This forward-only migration removes only objects owned by that
-- feature; it does not modify products, quotations, users, auth, or shared
-- security helpers.

-- Drop dependent Quick Quote configuration tables before their version parent.
-- Their constraints, indexes, policies, grants, triggers, and owned sequences
-- are dropped with their respective tables.
DROP TABLE IF EXISTS public.quick_quote_v2_runtime_configs;
DROP TABLE IF EXISTS public.quick_quote_config_allocations;
DROP TABLE IF EXISTS public.quick_quote_config_strength_priorities;
DROP TABLE IF EXISTS public.quick_quote_config_role_mappings;
DROP TABLE IF EXISTS public.quick_quote_config_rules;
DROP TABLE IF EXISTS public.quick_quote_budget_profiles;
DROP TABLE IF EXISTS public.quick_quote_config_versions;

-- Product mappings are independent from the versioned configuration tables.
DROP TABLE IF EXISTS public.quick_quote_product_mappings;

-- The tables above owned the triggers that referenced these functions.
DROP FUNCTION IF EXISTS public.apply_quick_quote_config(text, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.activate_quick_quote_config_version(uuid);
DROP FUNCTION IF EXISTS public.apply_quick_quote_v2_config(text, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.protect_quick_quote_config_version();
DROP FUNCTION IF EXISTS public.reject_quick_quote_config_child_mutation();
