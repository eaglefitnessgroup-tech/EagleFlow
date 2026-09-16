-- Active authenticated app users may create global products and upload their
-- initial product image. Product and image updates/deletes remain admin-only.

DROP POLICY IF EXISTS "Allow admin insert products" ON public.products;

CREATE POLICY "Allow active app user insert products" ON public.products
  FOR INSERT TO authenticated
  WITH CHECK (public.current_app_user_id() IS NOT NULL);

DROP POLICY IF EXISTS "EagleFlow QA upload product images"
  ON storage.objects;

DROP POLICY IF EXISTS "EagleFlow QA update product images"
  ON storage.objects;

DROP POLICY IF EXISTS "EagleFlow QA delete product images"
  ON storage.objects;

DROP POLICY IF EXISTS "Allow admin insert product-images" ON storage.objects;

CREATE POLICY "Allow active app user insert product-images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'product-images'
    AND public.current_app_user_id() IS NOT NULL
  );
