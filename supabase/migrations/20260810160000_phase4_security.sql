-- Phase 4 Security Remediation: Reservations Security

-- 1. Drop existing permissive policies
DROP POLICY IF EXISTS "Allow reservation delete" ON public.reservations;
DROP POLICY IF EXISTS "Allow reservation insert" ON public.reservations;
DROP POLICY IF EXISTS "Allow reservation read" ON public.reservations;
DROP POLICY IF EXISTS "Allow reservation update" ON public.reservations;

-- 2. Revoke permissive grants
REVOKE ALL ON public.reservations FROM anon, authenticated, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reservations TO authenticated;

-- Ensure RLS is enabled (it should be, but just in case)
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

-- 3. Create strictly isolated RLS policies

-- Read: Allow authenticated users to see all reservations (required for double-booking warnings)
CREATE POLICY "Allow authenticated read reservations" ON public.reservations
  FOR SELECT TO authenticated
  USING (true);

-- Insert: Enforce ownership (Salespersons can only insert their own, Admins can insert any)
CREATE POLICY "Allow authenticated insert reservations" ON public.reservations
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin() OR 
    reserved_by_id = public.current_app_user_id()
  );

-- Update: Enforce ownership (Salespersons can only update their own, and cannot reassign)
CREATE POLICY "Allow authenticated update reservations" ON public.reservations
  FOR UPDATE TO authenticated
  USING (
    public.is_admin() OR 
    reserved_by_id = public.current_app_user_id()
  )
  WITH CHECK (
    public.is_admin() OR 
    reserved_by_id = public.current_app_user_id()
  );

-- Delete: Enforce ownership (Salespersons can only delete their own)
CREATE POLICY "Allow authenticated delete reservations" ON public.reservations
  FOR DELETE TO authenticated
  USING (
    public.is_admin() OR 
    reserved_by_id = public.current_app_user_id()
  );
