import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_result.dart';
import 'sembast_auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseService _supabaseService;
  final SembastAuthRepository _localCache;

  SupabaseAuthRepository({
    required this._supabaseService,
    required this._localCache,
  });

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Invalid email or password.');
    }

    final client = _supabaseService.client;
    if (client == null) {
      return AuthResult.failure(
        'Offline login not supported. Please connect to the internet.',
      );
    }

    try {
      // 1. Authenticate with Supabase Auth
      final authResponse = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      if (authResponse.user == null) {
        return AuthResult.failure('Invalid email or password.');
      }

      final supabaseUid = authResponse.user!.id;

      // 2. Fetch app_users by supabase_uid safely
      final mappedUserResponse = await client
          .from('app_users')
          .select('id, name, email, username, role, is_active, created_at')
          .eq('supabase_uid', supabaseUid)
          .maybeSingle();

      if (mappedUserResponse == null) {
        await logout();
        return AuthResult.failure('Account mapping not found.');
      }

      if (mappedUserResponse['is_active'] != true) {
        await logout();
        return AuthResult.failure('This account is inactive.');
      }
      
      final roleStr = mappedUserResponse['role'] as String?;
      if (roleStr == null || (roleStr != 'admin' && roleStr != 'salesperson')) {
        await logout();
        return AuthResult.failure('Invalid account role.');
      }

      final appUser = AppUser(
        id: mappedUserResponse['id'] as String,
        name: mappedUserResponse['name'] as String,
        username: mappedUserResponse['username'] as String? ?? cleanEmail,
        passwordHash: '',
        role: UserRole.fromJson(roleStr),
        isActive: mappedUserResponse['is_active'] == true,
        createdAt: mappedUserResponse['created_at'] != null
            ? DateTime.parse(mappedUserResponse['created_at'] as String).toLocal()
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Cache session locally
      await _localCache.cacheSession(appUser);

      // 4. Refresh connectivity state since we are now authenticated
      await _supabaseService.healthCheck();

      return AuthResult.success(appUser);
    } on AuthException catch (_) {
      return AuthResult.failure('Invalid email or password.');
    } catch (e) {
      return AuthResult.failure(
        'Unable to complete authentication. Please try again.',
      );
    }
  }

  @override
  Future<void> logout() async {
    final client = _supabaseService.client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {
        // Ignored, proceed to clear local cache
      }
    }
    await _localCache.logout();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final client = _supabaseService.client;
    
    // Fail-closed session revalidation
    if (client == null || client.auth.currentUser == null) {
      await logout();
      return null;
    }

    final supabaseUid = client.auth.currentUser!.id;

    try {
      final response = await client
          .from('app_users')
          .select('id, name, email, username, role, is_active, created_at')
          .eq('supabase_uid', supabaseUid)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response == null || response['is_active'] != true) {
        await logout();
        return null;
      }
      
      final roleStr = response['role'] as String?;
      if (roleStr == null || (roleStr != 'admin' && roleStr != 'salesperson')) {
        await logout();
        return null;
      }

      final appUser = AppUser(
        id: response['id'] as String,
        name: response['name'] as String,
        username: response['username'] as String? ?? '',
        passwordHash: '',
        role: UserRole.fromJson(roleStr),
        isActive: response['is_active'] == true,
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'] as String).toLocal()
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update local cache with fresh data
      await _localCache.cacheSession(appUser);
      return appUser;
    } catch (e) {
      // Offline or network failure: Fail-closed.
      // We must NOT restore access from an unverified offline cache.
      await logout();
      return null;
    }
  }

  @override
  Future<List<AppUser>> getUsers() async {
    return _localCache.getUsers();
  }

  @override
  Future<bool> hasRememberedSession() async {
    return _localCache.hasRememberedSession();
  }

  @override
  Future<void> clearRememberedSession() async {
    await _localCache.clearRememberedSession();
  }
}
