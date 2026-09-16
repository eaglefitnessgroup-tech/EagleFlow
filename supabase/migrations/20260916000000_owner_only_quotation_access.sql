-- Every authenticated user, including admins, may access only their own quotations.

DROP POLICY IF EXISTS "Allow authenticated read quotations" ON public.quotations;
DROP POLICY IF EXISTS "Allow authenticated insert quotations" ON public.quotations;
DROP POLICY IF EXISTS "Allow authenticated update quotations" ON public.quotations;
DROP POLICY IF EXISTS "Allow authenticated delete quotations" ON public.quotations;

CREATE POLICY "Allow authenticated read own quotations" ON public.quotations
  FOR SELECT TO authenticated
  USING (salesperson_id = public.current_app_user_id());

CREATE POLICY "Allow authenticated insert own quotations" ON public.quotations
  FOR INSERT TO authenticated
  WITH CHECK (salesperson_id = public.current_app_user_id());

CREATE POLICY "Allow authenticated update own quotations" ON public.quotations
  FOR UPDATE TO authenticated
  USING (salesperson_id = public.current_app_user_id())
  WITH CHECK (salesperson_id = public.current_app_user_id());

CREATE POLICY "Allow authenticated delete own quotations" ON public.quotations
  FOR DELETE TO authenticated
  USING (salesperson_id = public.current_app_user_id());

DROP POLICY IF EXISTS "Allow authenticated read quotation_items" ON public.quotation_items;
DROP POLICY IF EXISTS "Allow authenticated insert quotation_items" ON public.quotation_items;
DROP POLICY IF EXISTS "Allow authenticated update quotation_items" ON public.quotation_items;
DROP POLICY IF EXISTS "Allow authenticated delete quotation_items" ON public.quotation_items;

CREATE POLICY "Allow authenticated read own quotation_items" ON public.quotation_items
  FOR SELECT TO authenticated
  USING (
    quotation_id IN (
      SELECT id
      FROM public.quotations
      WHERE salesperson_id = public.current_app_user_id()
    )
  );

CREATE POLICY "Allow authenticated insert own quotation_items" ON public.quotation_items
  FOR INSERT TO authenticated
  WITH CHECK (
    quotation_id IN (
      SELECT id
      FROM public.quotations
      WHERE salesperson_id = public.current_app_user_id()
    )
  );

CREATE POLICY "Allow authenticated update own quotation_items" ON public.quotation_items
  FOR UPDATE TO authenticated
  USING (
    quotation_id IN (
      SELECT id
      FROM public.quotations
      WHERE salesperson_id = public.current_app_user_id()
    )
  )
  WITH CHECK (
    quotation_id IN (
      SELECT id
      FROM public.quotations
      WHERE salesperson_id = public.current_app_user_id()
    )
  );

CREATE POLICY "Allow authenticated delete own quotation_items" ON public.quotation_items
  FOR DELETE TO authenticated
  USING (
    quotation_id IN (
      SELECT id
      FROM public.quotations
      WHERE salesperson_id = public.current_app_user_id()
    )
  );
