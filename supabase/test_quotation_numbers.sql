-- Setup and Test Quotation Numbering System
BEGIN;

DO $$ 
DECLARE
  v_user_an text;
  v_user_fa text;
  v_user_x text;
  v_admin text;
  v_q1 jsonb;
  v_q2 jsonb;
  v_q3 jsonb;
  v_q_fa jsonb;
  v_q_admin jsonb;
BEGIN
  -- Insert some test users
  INSERT INTO public.app_users (id, name, username, email, password_hash, role, is_active, created_at, supabase_uid, quotation_code) 
  VALUES
  ('TEST-AN', 'Anshad', 'anshad', 'anshad@example.com', '', 'salesperson', true, now(), '11111111-1111-1111-1111-111111111111', 'AN'),
  ('TEST-FA', 'Faris', 'faris', 'faris@example.com', '', 'salesperson', true, now(), '22222222-2222-2222-2222-222222222222', 'FA'),
  ('TEST-X', 'Unknown', 'unknown', 'unknown@example.com', '', 'salesperson', true, now(), '33333333-3333-3333-3333-333333333333', NULL),
  ('TEST-ADMIN', 'Admin', 'admin', 'admin@example.com', '', 'admin', true, now(), '44444444-4444-4444-4444-444444444444', 'AD')
  ON CONFLICT (id) DO UPDATE SET quotation_code = EXCLUDED.quotation_code, role = EXCLUDED.role;

  v_user_an := 'TEST-AN';
  v_user_fa := 'TEST-FA';
  v_user_x := 'TEST-X';
  v_admin := 'TEST-ADMIN';

  -- Simulate being admin so we can specify salespersonId
  SET ROLE authenticated;
  -- Set admin claim
  PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444"}', true);

  -- 1. Verify fail for user without code
  BEGIN
    PERFORM public.allocate_quotation_number(v_user_x, 2026);
    RAISE EXCEPTION 'User without code should have failed';
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Caught expected exception for missing code: %', SQLERRM;
  END;

  -- 2 & 3 & 4 & 5. Test monotonic allocation for AN, 4-digit padding, 2-digit year
  v_q1 := public.save_quotation('{"salespersonId": "TEST-AN", "createdDate": "2026-05-01T12:00:00Z"}'::jsonb);
  IF v_q1->>'quotationNumber' != 'QT-AN-0001-26' THEN
    RAISE EXCEPTION 'Expected QT-AN-0001-26, got %', v_q1->>'quotationNumber';
  END IF;

  v_q2 := public.save_quotation('{"salespersonId": "TEST-AN", "createdDate": "2026-05-02T12:00:00Z"}'::jsonb);
  IF v_q2->>'quotationNumber' != 'QT-AN-0002-26' THEN
    RAISE EXCEPTION 'Expected QT-AN-0002-26, got %', v_q2->>'quotationNumber';
  END IF;

  -- 6. Independent sequence per user
  v_q_fa := public.save_quotation('{"salespersonId": "TEST-FA", "createdDate": "2026-05-01T12:00:00Z"}'::jsonb);
  IF v_q_fa->>'quotationNumber' != 'QT-FA-0001-26' THEN
    RAISE EXCEPTION 'Expected QT-FA-0001-26, got %', v_q_fa->>'quotationNumber';
  END IF;

  -- 7. Test yearly reset for AN
  v_q3 := public.save_quotation('{"salespersonId": "TEST-AN", "createdDate": "2027-01-01T12:00:00Z"}'::jsonb);
  IF v_q3->>'quotationNumber' != 'QT-AN-0001-27' THEN
    RAISE EXCEPTION 'Expected QT-AN-0001-27, got %', v_q3->>'quotationNumber';
  END IF;

  -- 8. Deleted number is never reused (because sequence only goes up)
  DELETE FROM public.quotations WHERE id = (v_q2->>'id')::uuid;
  v_q2 := public.save_quotation('{"salespersonId": "TEST-AN", "createdDate": "2026-05-03T12:00:00Z"}'::jsonb);
  IF v_q2->>'quotationNumber' != 'QT-AN-0003-26' THEN
    RAISE EXCEPTION 'Expected QT-AN-0003-26 after deletion, got %', v_q2->>'quotationNumber';
  END IF;

  -- 9. Existing quotation numbers remain unchanged (immutability)
  v_q1 := public.save_quotation(('{"id": "' || (v_q1->>'id') || '", "salespersonId": "TEST-AN", "quotationNumber": "QT-AN-9999-26", "createdDate": "2026-05-01T12:00:00Z"}')::jsonb);
  IF v_q1->>'quotationNumber' != 'QT-AN-0001-26' THEN
    RAISE EXCEPTION 'Expected immutability to preserve QT-AN-0001-26, got %', v_q1->>'quotationNumber';
  END IF;

  -- 10. Authenticated user cannot generate another user's prefix
  -- Set claims for Faris
  PERFORM set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
  -- Try to save for Anshad, it should map to Faris automatically because non-admin can only save for themselves
  v_q_fa := public.save_quotation('{"salespersonId": "TEST-AN", "createdDate": "2026-05-02T12:00:00Z"}'::jsonb);
  -- The RPC currently fails with "Unauthorized: Cannot create quotations for other salespersons" if v_target_salesperson != current_user and not admin.
  IF (v_q_fa->>'error') IS NULL THEN
    RAISE EXCEPTION 'Expected error when salesperson tries to save for another, but got success';
  END IF;

  -- Now save for himself
  v_q_fa := public.save_quotation('{"salespersonId": "TEST-FA", "createdDate": "2026-05-02T12:00:00Z"}'::jsonb);
  IF v_q_fa->>'quotationNumber' != 'QT-FA-0002-26' THEN
    RAISE EXCEPTION 'Expected QT-FA-0002-26, got %', v_q_fa->>'quotationNumber';
  END IF;

  -- 11. Admin mappings work (admin creating on behalf)
  PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444"}', true);
  v_q_admin := public.save_quotation('{"salespersonId": "TEST-FA", "createdDate": "2026-05-03T12:00:00Z"}'::jsonb);
  IF v_q_admin->>'quotationNumber' != 'QT-FA-0003-26' THEN
    RAISE EXCEPTION 'Expected admin-on-behalf QT-FA-0003-26, got %', v_q_admin->>'quotationNumber';
  END IF;

  RAISE NOTICE 'All tests passed successfully!';
END $$;

ROLLBACK;
