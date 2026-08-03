import 'app_user.dart';

class AuthResult {
  final bool success;
  final String message;
  final AppUser? user;

  const AuthResult({required this.success, required this.message, this.user});

  factory AuthResult.success(AppUser user, {String message = 'Success'}) {
    return AuthResult(success: true, message: message, user: user);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(success: false, message: message, user: null);
  }
}
