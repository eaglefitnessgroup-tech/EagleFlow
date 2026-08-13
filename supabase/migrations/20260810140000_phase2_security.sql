-- Phase 2 Security Remediation: Products and Stock Backend Security

-- 1. Products Table Security
REVOKE ALL ON public.products FROM anon, authenticated, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO authenticated;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read products" ON public.products
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Allow admin insert products" ON public.products
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "Allow admin update products" ON public.products
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Allow admin delete products" ON public.products
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- 2. Stock Movements Table Security
REVOKE ALL ON public.stock_movements FROM anon, authenticated, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stock_movements TO authenticated;

ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read stock_movements" ON public.stock_movements
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Allow admin insert stock_movements" ON public.stock_movements
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "Allow admin update stock_movements" ON public.stock_movements
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Allow admin delete stock_movements" ON public.stock_movements
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- 3. get_current_stock Function Security
CREATE OR REPLACE FUNCTION public.get_current_stock(p_product_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
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
$$;

REVOKE ALL ON FUNCTION public.get_current_stock(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_current_stock(uuid) FROM anon;

GRANT EXECUTE ON FUNCTION public.get_current_stock(uuid) TO authenticated;
