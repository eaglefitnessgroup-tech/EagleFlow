-- Phase 8: Product Images Storage Bucket Setup

-- 1. Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- 2. (RLS is already enabled on storage.objects by Supabase)

-- 3. Read policy: Allow authenticated users to view/download images
CREATE POLICY "Allow authenticated read product-images" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'product-images');

-- 4. Insert policy: Allow admins to upload new images
CREATE POLICY "Allow admin insert product-images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

-- 5. Update policy: Allow admins to replace existing images
CREATE POLICY "Allow admin update product-images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'product-images' AND public.is_admin())
  WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

-- 6. Delete policy: Allow admins to remove images
CREATE POLICY "Allow admin delete product-images" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'product-images' AND public.is_admin());