import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/authentication/application/auth_controller.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';

class FakeAuthRepository implements AuthRepository {
  AppUser? simulatedCurrentUser;
  bool shouldThrowOnLogin = false;
  bool hasClearedSession = false;
  bool hasLoggedOut = false;

  final _testAdmin = AppUser(
    id: 'ADMIN',
    name: 'Admin',
    username: 'admin',
    passwordHash: 'hashed1',
    role: UserRole.admin,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final _testSales = AppUser(
    id: 'SALES',
    name: 'Sales',
    username: 'sales',
    passwordHash: 'hashed2',
    role: UserRole.sales,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<AppUser?> getCurrentUser() async {
    return simulatedCurrentUser;
  }

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(
      const Duration(milliseconds: 10),
    ); // Add slight delay to test duplicate prevention

    if (shouldThrowOnLogin) {
      throw Exception('Simulated network error');
    }
    if (username == 'admin' && password == 'pass') {
      return AuthResult.success(_testAdmin);
    } else if (username == 'sales' && password == 'pass') {
      return AuthResult.success(_testSales);
    } else {
      return AuthResult.failure('Invalid credentials');
    }
  }

  @override
  Future<void> logout() async {
    hasLoggedOut = true;
    simulatedCurrentUser = null;
  }

  @override
  Future<bool> hasRememberedSession() async {
    return simulatedCurrentUser != null;
  }

  @override
  Future<void> clearRememberedSession() async {
    hasClearedSession = true;
  }

  @override
  Future<List<AppUser>> getUsers() async {
    return [_testAdmin, _testSales];
  }
}

void main() {
  group('AuthController Tests', () {
    late FakeAuthRepository fakeRepo;
    late AuthController controller;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      controller = AuthController(fakeRepo);
    });

    test('1. Initialize without session leaves currentUser null', () async {
      await controller.initialize();
      expect(controller.currentUser, isNull);
      expect(controller.isAuthenticated, false);
      expect(controller.isInitializing, false);
    });

    test('2. Initialize with remembered user sets currentUser', () async {
      fakeRepo.simulatedCurrentUser = fakeRepo._testAdmin;
      await controller.initialize();

      expect(controller.currentUser, isNotNull);
      expect(controller.isAuthenticated, true);
      expect(controller.isAdmin, true);
    });

    test('3. Admin and sales getters work', () async {
      fakeRepo.simulatedCurrentUser = fakeRepo._testAdmin;
      await controller.initialize();
      expect(controller.isAdmin, true);
      expect(controller.isSales, false);

      fakeRepo.simulatedCurrentUser = fakeRepo._testSales;
      await controller.initialize();
      expect(controller.isAdmin, false);
      expect(controller.isSales, true);
    });

    test('4. Successful login updates state and returns true', () async {
      final result = await controller.login(
        username: 'admin',
        password: 'pass',
        rememberMe: true,
      );

      expect(result, true);
      expect(controller.currentUser, isNotNull);
      expect(controller.isAuthenticated, true);
      expect(controller.errorMessage, isNull);
      expect(fakeRepo.hasClearedSession, false); // rememberMe is true
    });

    test('5. Failed login sets error message and keeps user null', () async {
      final result = await controller.login(
        username: 'wrong',
        password: 'wrong',
        rememberMe: true,
      );

      expect(result, false);
      expect(controller.currentUser, isNull);
      expect(controller.isAuthenticated, false);
      expect(controller.errorMessage, 'Invalid credentials');
    });

    test('6. Duplicate login prevention', () async {
      fakeRepo.shouldThrowOnLogin = false;

      // Start first request
      final future1 = controller.login(
        username: 'admin',
        password: 'pass',
        rememberMe: true,
      );

      // Since it's delayed, isLoading will be true right away
      expect(controller.isLoading, true);

      // Start second request
      final future2 = controller.login(
        username: 'sales',
        password: 'pass',
        rememberMe: true,
      );

      final result2 = await future2;
      expect(result2, false); // Blocked because isLoading is true

      final result1 = await future1;
      expect(result1, true); // First succeeds
      expect(controller.currentUser!.username, 'admin');
    });

    test(
      '7. rememberMe false clears persisted session but keeps runtime user',
      () async {
        final result = await controller.login(
          username: 'sales',
          password: 'pass',
          rememberMe: false,
        );

        expect(result, true);
        expect(controller.currentUser, isNotNull);
        expect(
          fakeRepo.hasClearedSession,
          true,
        ); // Should clear persisted session
      },
    );

    test('8. Logout clears current user and notifies', () async {
      await controller.login(
        username: 'admin',
        password: 'pass',
        rememberMe: true,
      );
      expect(controller.isAuthenticated, true);

      await controller.logout();
      expect(controller.isAuthenticated, false);
      expect(controller.currentUser, isNull);
      expect(fakeRepo.hasLoggedOut, true);
    });

    test('9. Unexpected exception sets generic error message', () async {
      fakeRepo.shouldThrowOnLogin = true;
      final result = await controller.login(
        username: 'admin',
        password: 'pass',
        rememberMe: true,
      );

      expect(result, false);
      expect(controller.currentUser, isNull);
      expect(
        controller.errorMessage,
        'Unable to complete authentication. Please try again.',
      );
    });
  });
}
