import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/application/salesperson_name_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppUser user(String id, String name, {UserRole role = UserRole.sales}) {
    final now = DateTime(2026, 9, 16);
    return AppUser(
      id: id,
      name: name,
      username: name.toLowerCase(),
      passwordHash: '',
      role: role,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SalespersonNameResolver', () {
    test('current Shijo wins over stale Nabeel profile with the same ID', () {
      final shijo = user('SALES-003', 'Shijo');
      final staleNabeel = user('SALES-003', 'Nabeel');

      final result = SalespersonNameResolver.resolve(
        salespersonId: shijo.id,
        currentUser: shijo,
        profiles: [staleNabeel],
      );

      expect(result, 'Shijo');
      expect(result, isNot('Nabeel'));
    });

    test('resolves Nabeel from the current authenticated profile', () {
      final nabeel = user('SALES-003', 'Nabeel');

      expect(
        SalespersonNameResolver.resolve(
          salespersonId: nabeel.id,
          currentUser: nabeel,
        ),
        'Nabeel',
      );
    });

    test('resolves Anshad from the current authenticated profile', () {
      final anshad = user('ADMIN-001', 'Anshad', role: UserRole.admin);

      expect(
        SalespersonNameResolver.resolve(
          salespersonId: anshad.id,
          currentUser: anshad,
        ),
        'Anshad',
      );
    });

    test('resolves an arbitrary unseeded current user by AppUser name', () {
      final unseeded = user('USER-NEW-8472', 'Mehboob');

      expect(
        SalespersonNameResolver.resolve(
          salespersonId: unseeded.id,
          currentUser: unseeded,
        ),
        'Mehboob',
      );
    });

    test('falls back to an exact profile match and then the ID', () {
      final faris = user('ADMIN-002', 'Faris', role: UserRole.admin);

      expect(
        SalespersonNameResolver.resolve(
          salespersonId: faris.id,
          profiles: [faris],
        ),
        'Faris',
      );
      expect(
        SalespersonNameResolver.resolve(salespersonId: 'UNKNOWN-001'),
        'UNKNOWN-001',
      );
    });

    test('switching users does not retain the previous salesman name', () {
      final shijo = user('SALES-005', 'Shijo');
      final nabeel = user('SALES-003', 'Nabeel');

      expect(
        SalespersonNameResolver.resolve(
          salespersonId: shijo.id,
          currentUser: shijo,
        ),
        'Shijo',
      );
      expect(
        SalespersonNameResolver.resolve(
          salespersonId: nabeel.id,
          currentUser: nabeel,
        ),
        'Nabeel',
      );
    });
  });
}
