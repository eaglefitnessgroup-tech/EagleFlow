-- Run after 20260930000000_add_quotation_revisions.sql in a disposable database.
BEGIN;

INSERT INTO public.app_users (
  id,
  name,
  username,
  email,
  password_hash,
  role,
  is_active,
  created_at,
  supabase_uid,
  quotation_code
)
VALUES
  (
    'REVISION-OWNER',
    'Revision Owner',
    'revision-owner',
    'revision-owner@example.com',
    '',
    'salesperson',
    true,
    now(),
    '91000000-0000-0000-0000-000000000001',
    'RV'
  ),
  (
    'REVISION-OTHER',
    'Revision Other',
    'revision-other',
    'revision-other@example.com',
    '',
    'salesperson',
    true,
    now(),
    '91000000-0000-0000-0000-000000000002',
    'RO'
  )
ON CONFLICT (id) DO NOTHING;

SET ROLE authenticated;
SET request.jwt.claims TO
  '{"sub": "91000000-0000-0000-0000-000000000001"}';

DO $$
DECLARE
  v_original jsonb;
  v_revision_1 jsonb;
  v_revision_2 jsonb;
  v_revision_3 jsonb;
  v_original_source_r1 jsonb;
  v_original_source_r2 jsonb;
  v_original_source_r3 jsonb;
  v_revision_source_r1 jsonb;
  v_revision_source_r2 jsonb;
  v_revision_source_r3 jsonb;
  v_edit_result jsonb;
  v_second_original jsonb;
  v_original_id uuid;
  v_revision_1_id uuid;
  v_original_source_id uuid := '94000000-0000-0000-0000-000000000001';
  v_revision_source_id uuid := '95000000-0000-0000-0000-000000000001';
  v_original_item_id uuid;
  v_revision_item_id uuid;
  v_original_customer text;
BEGIN
  v_original := public.save_quotation(
    '{
      "salespersonId": "REVISION-OWNER",
      "createdDate": "2026-09-30T08:00:00Z",
      "customerInfo": {"name": "Original Customer"},
      "lineItems": [{
        "id": "92000000-0000-0000-0000-000000000001",
        "name": "Original Item",
        "brand": "Snapshot Brand",
        "condition": "used",
        "unitPrice": 100,
        "quantity": 2,
        "discount": 5,
        "description": "Snapshot description",
        "isCustom": true,
        "isVatApplicable": false,
        "imagePath": "quotation-images/source.png",
        "imageId": "source-image"
      }]
    }'::jsonb
  );

  IF v_original->>'error' IS NOT NULL THEN
    RAISE EXCEPTION 'Original save failed: %', v_original->>'error';
  END IF;

  v_original_id := (v_original->>'id')::uuid;

  -- A standalone original remains editable.
  v_edit_result := public.save_quotation(
    pg_catalog.jsonb_build_object(
      'id', v_original_id::text,
      'quotationNumber', v_original->>'quotationNumber',
      'salespersonId', 'REVISION-OWNER',
      'customerInfo', pg_catalog.jsonb_build_object(
        'name', 'Edited Before Revision'
      ),
      'lineItems', '[]'::jsonb
    )
  );
  IF v_edit_result->>'error' IS NOT NULL THEN
    RAISE EXCEPTION 'Standalone original should remain editable: %',
      v_edit_result->>'error';
  END IF;

  -- Restore an item so item immutability/fresh-ID behavior can be asserted.
  v_edit_result := public.save_quotation(
    pg_catalog.jsonb_build_object(
      'id', v_original_id::text,
      'quotationNumber', v_original->>'quotationNumber',
      'salespersonId', 'REVISION-OWNER',
      'customerInfo', pg_catalog.jsonb_build_object(
        'name', 'Edited Before Revision'
      ),
      'lineItems', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', '92000000-0000-0000-0000-000000000002',
          'name', 'Original Item',
          'brand', 'Snapshot Brand',
          'condition', 'used',
          'unitPrice', 100,
          'quantity', 2,
          'discount', 5,
          'description', 'Snapshot description',
          'isCustom', true,
          'isVatApplicable', false,
          'imagePath', 'quotation-images/source.png',
          'imageId', 'source-image'
        )
      )
    )
  );

  SELECT customer_name
  INTO v_original_customer
  FROM public.quotations
  WHERE id = v_original_id;

  SELECT id
  INTO v_original_item_id
  FROM public.quotation_items
  WHERE quotation_id = v_original_id;

  v_revision_1 := public.create_quotation_revision(
    v_original_id,
    '{
      "customerInfo": {
        "name": "Revision Customer",
        "company": "Revision Company",
        "phone": "123",
        "email": "revision@example.com",
        "projectLocation": "Dubai"
      },
      "salespersonId": "REVISION-OWNER",
      "charges": {
        "deliveryCharges": 10,
        "installationCharges": 20,
        "otherCharges": 30,
        "overallDiscount": 40,
        "vatPercentage": 5
      },
      "customerNotes": "Customer note",
      "internalNotes": "Internal note",
      "validUntil": "2026-10-30T08:00:00Z",
      "expectedDelivery": "2026-10-10T08:00:00Z",
      "lineItems": [{
        "id": "92000000-0000-0000-0000-000000000002",
        "name": "Original Item",
        "brand": "Snapshot Brand",
        "condition": "used",
        "unitPrice": 125,
        "quantity": 3,
        "discount": 7,
        "description": "Revised description",
        "isCustom": true,
        "isVatApplicable": false,
        "imagePath": "quotation-images/source.png",
        "imageId": "source-image"
      }]
    }'::jsonb
  );

  IF v_revision_1->>'error' IS NOT NULL THEN
    RAISE EXCEPTION 'R1 creation failed: %', v_revision_1->>'error';
  END IF;
  IF v_revision_1->>'quotation_number' <> v_original->>'quotationNumber'
     OR (v_revision_1->>'revision_no')::integer <> 1
     OR (v_revision_1->>'base_quotation_id')::uuid <> v_original_id THEN
    RAISE EXCEPTION 'R1 identity is incorrect: %', v_revision_1;
  END IF;

  v_revision_1_id := (v_revision_1->>'id')::uuid;
  SELECT id
  INTO v_revision_item_id
  FROM public.quotation_items
  WHERE quotation_id = v_revision_1_id;

  IF v_revision_item_id = v_original_item_id THEN
    RAISE EXCEPTION 'Revision item must receive a fresh ID.';
  END IF;
  IF (SELECT customer_name FROM public.quotations WHERE id = v_original_id)
     <> v_original_customer THEN
    RAISE EXCEPTION 'Original quotation was mutated while creating R1.';
  END IF;
  IF (SELECT id FROM public.quotation_items WHERE quotation_id = v_original_id)
     <> v_original_item_id THEN
    RAISE EXCEPTION 'Original quotation item was mutated while creating R1.';
  END IF;

  v_revision_2 := public.create_quotation_revision(
    v_revision_1_id,
    '{"customerInfo":{"name":"R2 Source"}}'::jsonb
  );
  v_revision_3 := public.create_quotation_revision(
    (v_revision_2->>'id')::uuid,
    '{"customerInfo":{"name":"R3 From R2"}}'::jsonb
  );

  IF v_revision_2->>'quotation_number' <> v_original->>'quotationNumber'
     OR (v_revision_2->>'revision_no')::integer <> 2
     OR v_revision_3->>'quotation_number' <> v_original->>'quotationNumber'
     OR (v_revision_3->>'revision_no')::integer <> 3 THEN
    RAISE EXCEPTION 'R2/R3 numbering is incorrect: %, %',
      v_revision_2,
      v_revision_3;
  END IF;
  IF (SELECT customer_name FROM public.quotations
      WHERE id = (v_revision_3->>'id')::uuid) <> 'R3 From R2' THEN
    RAISE EXCEPTION 'R3 did not copy the selected R2 payload.';
  END IF;
  IF (SELECT customer_name FROM public.quotations WHERE id = v_original_id)
       <> v_original_customer
     OR (SELECT customer_name FROM public.quotations
         WHERE id = v_revision_1_id) <> 'Revision Customer'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = (v_revision_2->>'id')::uuid) <> 'R2 Source' THEN
    RAISE EXCEPTION 'Existing family members changed while creating R3.';
  END IF;

  -- With Original/R1/R2 present, revising Original still allocates R3 and
  -- uses the selected Original payload as the new snapshot.
  INSERT INTO public.quotations (
    id,
    quotation_number,
    salesperson_id,
    customer_name,
    valid_until
  ) VALUES (
    v_original_source_id,
    'QT-RV-SOURCE-ORIGINAL-26',
    'REVISION-OWNER',
    'Original Source Content',
    now()
  );
  v_original_source_r1 := public.create_quotation_revision(
    v_original_source_id,
    '{"customerInfo":{"name":"Original Family R1"}}'::jsonb
  );
  v_original_source_r2 := public.create_quotation_revision(
    (v_original_source_r1->>'id')::uuid,
    '{"customerInfo":{"name":"Original Family R2"}}'::jsonb
  );
  v_original_source_r3 := public.create_quotation_revision(
    v_original_source_id,
    '{"customerInfo":{"name":"Copied Original Source Content"}}'::jsonb
  );
  IF v_original_source_r1->>'error' IS NOT NULL
     OR v_original_source_r2->>'error' IS NOT NULL
     OR v_original_source_r3->>'error' IS NOT NULL
     OR (v_original_source_r3->>'revision_no')::integer <> 3 THEN
    RAISE EXCEPTION 'Revise-from-Original did not allocate R3: %, %, %',
      v_original_source_r1,
      v_original_source_r2,
      v_original_source_r3;
  END IF;
  IF (SELECT customer_name FROM public.quotations
      WHERE id = (v_original_source_r3->>'id')::uuid)
       <> 'Copied Original Source Content'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = v_original_source_id) <> 'Original Source Content'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = (v_original_source_r1->>'id')::uuid)
       <> 'Original Family R1'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = (v_original_source_r2->>'id')::uuid)
       <> 'Original Family R2' THEN
    RAISE EXCEPTION 'Revise-from-Original copied or mutated incorrect content.';
  END IF;

  -- With Original/R1/R2 present, revising R1 also allocates R3 and uses R1
  -- as the selected content source.
  INSERT INTO public.quotations (
    id,
    quotation_number,
    salesperson_id,
    customer_name,
    valid_until
  ) VALUES (
    v_revision_source_id,
    'QT-RV-SOURCE-R1-26',
    'REVISION-OWNER',
    'R1 Family Original',
    now()
  );
  v_revision_source_r1 := public.create_quotation_revision(
    v_revision_source_id,
    '{"customerInfo":{"name":"Selected R1 Content"}}'::jsonb
  );
  v_revision_source_r2 := public.create_quotation_revision(
    (v_revision_source_r1->>'id')::uuid,
    '{"customerInfo":{"name":"R1 Family R2"}}'::jsonb
  );
  v_revision_source_r3 := public.create_quotation_revision(
    (v_revision_source_r1->>'id')::uuid,
    '{"customerInfo":{"name":"Copied Selected R1 Content"}}'::jsonb
  );
  IF v_revision_source_r1->>'error' IS NOT NULL
     OR v_revision_source_r2->>'error' IS NOT NULL
     OR v_revision_source_r3->>'error' IS NOT NULL
     OR (v_revision_source_r3->>'revision_no')::integer <> 3 THEN
    RAISE EXCEPTION 'Revise-from-R1 did not allocate R3: %, %, %',
      v_revision_source_r1,
      v_revision_source_r2,
      v_revision_source_r3;
  END IF;
  IF (SELECT customer_name FROM public.quotations
      WHERE id = (v_revision_source_r3->>'id')::uuid)
       <> 'Copied Selected R1 Content'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = v_revision_source_id) <> 'R1 Family Original'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = (v_revision_source_r1->>'id')::uuid)
       <> 'Selected R1 Content'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = (v_revision_source_r2->>'id')::uuid)
       <> 'R1 Family R2' THEN
    RAISE EXCEPTION 'Revise-from-R1 copied or mutated incorrect content.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.quotations
    WHERE base_quotation_id IS NOT NULL
    GROUP BY base_quotation_id, revision_no
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate family revision numbers were created.';
  END IF;

  IF pg_catalog.pg_get_functiondef(
       'public.create_quotation_revision(uuid,jsonb)'::regprocedure
     ) !~* 'FOR UPDATE'
     OR pg_catalog.pg_get_functiondef(
       'public.create_quotation_revision(uuid,jsonb)'::regprocedure
     ) !~* 'MAX\s*\(quotation\.revision_no\)' THEN
    RAISE EXCEPTION 'Revision allocation lost its family lock or MAX calculation.';
  END IF;

  -- Revision content remains immutable through the normal save path.
  v_edit_result := public.save_quotation(
    pg_catalog.jsonb_build_object(
      'id', v_revision_1_id::text,
      'salespersonId', 'REVISION-OWNER',
      'customerInfo', pg_catalog.jsonb_build_object('name', 'Forbidden')
    )
  );
  IF v_edit_result->>'error' NOT LIKE 'Saved quotation revisions are immutable.%' THEN
    RAISE EXCEPTION 'Revision update should be rejected: %', v_edit_result;
  END IF;

  -- Original content remains editable after revisions exist, without changing
  -- the existing R1/R2 snapshots or any family identity metadata.
  v_edit_result := public.save_quotation(
    pg_catalog.jsonb_build_object(
      'id', v_original_id::text,
      'quotationNumber', 'ATTEMPTED-RENUMBER',
      'salespersonId', 'REVISION-OWNER',
      'customerInfo', pg_catalog.jsonb_build_object(
        'name', 'Edited After Revisions'
      ),
      'lineItems', '[]'::jsonb
    )
  );
  IF v_edit_result->>'error' IS NOT NULL THEN
    RAISE EXCEPTION 'Original-with-history content edit failed: %',
      v_edit_result->>'error';
  END IF;
  IF (SELECT customer_name FROM public.quotations WHERE id = v_original_id)
       <> 'Edited After Revisions'
     OR (SELECT quotation_number FROM public.quotations
         WHERE id = v_original_id) <> v_original->>'quotationNumber'
     OR (SELECT base_quotation_id FROM public.quotations
         WHERE id = v_original_id) IS NOT NULL
     OR (SELECT revision_no FROM public.quotations
         WHERE id = v_original_id) <> 0 THEN
    RAISE EXCEPTION 'Original edit changed identity or failed to save content.';
  END IF;
  IF (SELECT customer_name FROM public.quotations
      WHERE id = v_revision_1_id) <> 'Revision Customer'
     OR (SELECT customer_name FROM public.quotations
         WHERE id = (v_revision_2->>'id')::uuid) <> 'R2 Source' THEN
    RAISE EXCEPTION 'Original edit mutated an existing revision snapshot.';
  END IF;

  BEGIN
    UPDATE public.quotations
    SET id = '96000000-0000-0000-0000-000000000001'
    WHERE id = v_original_id;
    RAISE EXCEPTION 'Original ID mutation was accepted.';
  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm NOT LIKE 'Quotation identity,%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    UPDATE public.quotations
    SET quotation_number = 'QT-MUTATED-26'
    WHERE id = v_original_id;
    RAISE EXCEPTION 'Original quotation-number mutation was accepted.';
  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm NOT LIKE 'Quotation identity,%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    UPDATE public.quotations
    SET base_quotation_id = v_original_source_id
    WHERE id = v_original_id;
    RAISE EXCEPTION 'Original base-quotation mutation was accepted.';
  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm NOT LIKE 'Quotation identity,%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    UPDATE public.quotations
    SET revision_no = 99
    WHERE id = v_original_id;
    RAISE EXCEPTION 'Original revision-number mutation was accepted.';
  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm NOT LIKE 'Quotation identity,%' THEN
        RAISE;
      END IF;
  END;

  -- Revisions must not consume the normal quotation sequence.
  v_second_original := public.save_quotation(
    '{
      "salespersonId":"REVISION-OWNER",
      "createdDate":"2026-09-30T09:00:00Z"
    }'::jsonb
  );
  IF v_original->>'quotationNumber' <> 'QT-RV-0001-26'
     OR v_second_original->>'quotationNumber' <> 'QT-RV-0002-26' THEN
    RAISE EXCEPTION 'Revision creation changed normal numbering: %, %',
      v_original,
      v_second_original;
  END IF;

  -- Invalid revision shape and duplicate number/revision pairs are constrained.
  BEGIN
    INSERT INTO public.quotations (
      id,
      quotation_number,
      salesperson_id,
      revision_no,
      valid_until
    ) VALUES (
      '93000000-0000-0000-0000-000000000001',
      'QT-INVALID-26',
      'REVISION-OWNER',
      1,
      now()
    );
    RAISE EXCEPTION 'Invalid revision shape was accepted.';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.quotations (
      id,
      quotation_number,
      salesperson_id,
      revision_no,
      valid_until
    ) VALUES (
      '93000000-0000-0000-0000-000000000002',
      v_original->>'quotationNumber',
      'REVISION-OWNER',
      0,
      now()
    );
    RAISE EXCEPTION 'Duplicate quotation number/revision was accepted.';
  EXCEPTION
    WHEN unique_violation THEN NULL;
  END;
END;
$$;

SET request.jwt.claims TO
  '{"sub": "91000000-0000-0000-0000-000000000002"}';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT public.create_quotation_revision(
    quotation.id,
    '{}'::jsonb
  )
  INTO v_result
  FROM public.quotations quotation
  WHERE quotation.salesperson_id = 'REVISION-OWNER'
  LIMIT 1;

  -- RLS hides the other user's source, so no row may be selected. Direct use of
  -- a known ID must still return an authorization-safe not-found error.
  SELECT public.create_quotation_revision(
    (
      SELECT id
      FROM public.quotations
      WHERE salesperson_id = 'REVISION-OWNER'
      LIMIT 1
    ),
    '{}'::jsonb
  ) INTO v_result;

  IF v_result IS NOT NULL
     AND v_result->>'error' IS NULL THEN
    RAISE EXCEPTION 'Unauthorized revision creation was accepted: %', v_result;
  END IF;
END;
$$;

ROLLBACK;
