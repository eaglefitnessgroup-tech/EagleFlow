import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';

void main() {
  group('AuthResult Tests', () {
    final now = DateTime.now();
    final testUser = AppUser(
      id: 'USR-001',
      name: 'John Doe',
      username: 'john@eagleflow.com',
      passwordHash: 'hashed123',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('AuthResult.success creates correct success instance', () {
      final result = AuthResult.success(testUser);

      expect(result.success, true);
      expect(result.message, 'Success');
      expect(result.user, testUser);
    });

    test(
      'AuthResult.success creates correct success instance with custom message',
      () {
        final result = AuthResult.success(testUser, message: 'Welcome back!');

        expect(result.success, true);
        expect(result.message, 'Welcome back!');
        expect(result.user, testUser);
      },
    );

    test('AuthResult.failure creates correct failure instance', () {
      final result = AuthResult.failure('Invalid credentials');

      expect(result.success, false);
      expect(result.message, 'Invalid credentials');
      expect(result.user, isNull);
    });
  });
}
