import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordUtils {
  PasswordUtils._();

  static const String _salt = 'eagleflow_offline_salt_v1';

  static String hashPassword(String password) {
    final bytes = utf8.encode(password + _salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPassword(String password, String passwordHash) {
    return hashPassword(password) == passwordHash;
  }
}
