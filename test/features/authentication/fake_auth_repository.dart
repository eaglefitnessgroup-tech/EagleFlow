import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';

class FakeAuthRepository implements AuthRepository {
  AppUser? simulatedCurrentUser;
  bool shouldThrowOnLogin = false;
  bool hasClearedSession = false;
  bool hasLoggedOut = false;

  final testAdmin = AppUser(
    id: 'ADMIN-001',
    name: 'Anshad',
    username: 'anshad',
    passwordHash: 'hashed1',
    role: UserRole.admin,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testSales = AppUser(
    id: 'SALES-001',
    name: 'Ajmal',
    username: 'ajmal',
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
    required String email,
    required String password,
  }) async {
    await Future.delayed(
      const Duration(milliseconds: 10),
    ); // Add slight delay to test duplicate prevention

    if (shouldThrowOnLogin) {
      throw Exception('Simulated network error');
    }
    if (email == 'admin@eagleflow.com' && password == 'pass') {
      return AuthResult.success(testAdmin);
    } else if (email == 'sales@eagleflow.com' && password == 'pass') {
      return AuthResult.success(testSales);
    } else if (email == 'anshad@eagleflow.com' && password == 'anshad123') {
      return AuthResult.success(testAdmin);
    } else if (email == 'ajmal@eagleflow.com' && password == 'ajmal123') {
      return AuthResult.success(testSales);
    } else {
      return AuthResult.failure('Invalid email or password.');
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
    return [testAdmin, testSales];
  }
}
