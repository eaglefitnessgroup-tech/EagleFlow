import 'app_user.dart';
import 'auth_result.dart';

/// Abstract repository for Authentication operations.
abstract class AuthRepository {
  /// Attempts to authenticate a user with [email] and [password].
  ///
  /// The implementation should:
  /// - Perform case-insensitive email comparison.
  /// - Ignore leading/trailing spaces on the email.
  ///
  /// Returns an [AuthResult] containing the user if successful, or an error message.
  Future<AuthResult> login({
    required String email,
    required String password,
  });

  /// Logs out the current user and clears the session.
  Future<void> logout();

  /// Retrieves the currently authenticated user.
  /// Returns null if no valid session exists.
  Future<AppUser?> getCurrentUser();

  /// Retrieves all users in the system.
  Future<List<AppUser>> getUsers();

  /// Checks if a session has been remembered.
  Future<bool> hasRememberedSession();

  /// Clears the remembered session data.
  Future<void> clearRememberedSession();
}
