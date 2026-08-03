import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';

void main() {
  group('AppUser Model Tests', () {
    final now = DateTime.now();
    final testUser = AppUser(
      id: 'USR-001',
      name: 'John Doe',
      username: 'john@eagleflow.com',
      passwordHash: 'hashed123',
      role: UserRole.admin,
      isActive: true,
      createdAt: now,
    );

    test('1. JSON round-trip serialization', () {
      final json = testUser.toJson();
      final fromJsonUser = AppUser.fromJson(json);

      expect(fromJsonUser.id, testUser.id);
      expect(fromJsonUser.name, testUser.name);
      expect(fromJsonUser.username, testUser.username);
      expect(fromJsonUser.passwordHash, testUser.passwordHash);
      expect(fromJsonUser.role, testUser.role);
      expect(fromJsonUser.isActive, testUser.isActive);
      // Since toIso8601String loses microsecond precision occasionally depending on the environment,
      // we check if they are close enough or just rely on the equality operator if it handles it.
      // But we can just use the overridden operator == which checks strict equality.
      // Note: DateTime.parse().toLocal() might have slight differences if the original wasn't UTC,
      // but in this controlled test they should be identical except for maybe microsecond loss.
      expect(
        fromJsonUser.createdAt.difference(testUser.createdAt).inSeconds,
        0,
      );
    });

    test('2. Default values when fromJson is missing fields', () {
      final json = <String, dynamic>{
        'id': 'USR-002',
        // Missing name, username, passwordHash, role, isActive, createdAt
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 'USR-002');
      expect(user.name, '');
      expect(user.username, '');
      expect(user.passwordHash, '');
      expect(user.role, UserRole.salesperson); // Default role
      expect(user.isActive, true); // Default active status
      expect(user.createdAt, isA<DateTime>());
    });

    test('3. Invalid role defaults to salesperson safely', () {
      final json = {
        'id': 'USR-003',
        'role': 'super_admin', // Invalid role
      };

      final user = AppUser.fromJson(json);
      expect(user.role, UserRole.salesperson);
    });

    test('4. Role getters function correctly', () {
      final admin = testUser.copyWith(role: UserRole.admin);
      final sales = testUser.copyWith(role: UserRole.salesperson);

      expect(admin.isAdmin, true);
      expect(admin.isSalesperson, false);

      expect(sales.isAdmin, false);
      expect(sales.isSalesperson, true);
    });

    test('5. copyWith works correctly', () {
      final updatedUser = testUser.copyWith(name: 'Jane Doe', isActive: false);

      expect(updatedUser.name, 'Jane Doe');
      expect(updatedUser.isActive, false);

      // Unchanged fields should remain the same
      expect(updatedUser.id, testUser.id);
      expect(updatedUser.username, testUser.username);
      expect(updatedUser.role, testUser.role);
    });

    test('6. toString does not expose passwordHash', () {
      final stringRepresentation = testUser.toString();
      expect(stringRepresentation.contains('hashed123'), false);
      expect(stringRepresentation.contains('passwordHash'), false);
      expect(stringRepresentation.contains('USR-001'), true);
    });
  });
}
