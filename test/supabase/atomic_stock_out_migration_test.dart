import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20261106000000_atomic_stock_out_by_quotation.sql';
  late String migration;

  setUpAll(() {
    final file = File(migrationPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Stock-out migration is missing.',
    );
    migration = file.readAsStringSync();
  });

  test(
    'duplicate processing is serialized and returns without reinserting',
    () {
      final rowLock = migration.indexOf('FOR UPDATE;');
      final duplicateGuard = migration.indexOf('IF v_already_processed THEN');
      final movementInsert = migration.indexOf(
        'INSERT INTO public.stock_movements',
      );

      expect(rowLock, greaterThan(0));
      expect(duplicateGuard, greaterThan(rowLock));
      expect(movementInsert, greaterThan(duplicateGuard));
      expect(
        migration.indexOf('already_processed', duplicateGuard),
        greaterThan(duplicateGuard),
      );
      expect(
        migration,
        contains('A processed quotation cannot be reset for stock out.'),
      );
    },
  );

  test('movement, reservation, and quotation updates share one RPC body', () {
    expect(
      migration,
      contains('CREATE OR REPLACE FUNCTION public.process_quotation_stock_out'),
    );
    expect(migration, contains('UPDATE public.reservations'));
    expect(migration, contains('UPDATE public.quotations'));
    expect(migration, isNot(contains('WHEN OTHERS')));
    expect(migration, contains("'processed_at', v_now"));
  });

  test('admin read access is narrow and unauthorized RPC access is denied', () {
    expect(
      migration,
      contains('Allow admins read quotations for stock processing'),
    );
    expect(
      migration,
      contains('Allow admins read quotation items for stock processing'),
    );
    expect(migration, contains('FOR SELECT TO authenticated'));
    expect(migration, isNot(contains('FOR UPDATE TO authenticated')));

    final authorization = migration.indexOf(
      'IF auth.uid() IS NULL OR NOT COALESCE(public.is_admin(), false)',
    );
    final quotationLookup = migration.indexOf(
      'FROM public.quotations quotation',
    );
    expect(authorization, greaterThan(0));
    expect(quotationLookup, greaterThan(authorization));
    expect(migration, contains("ERRCODE = '42501'"));
    expect(
      migration,
      contains(
        'REVOKE ALL ON FUNCTION public.process_quotation_stock_out(text)',
      ),
    );
  });
}
