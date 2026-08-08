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
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Invalid username or password.');
    }

    final client = _supabaseService.client;
    if (client == null) {
      return AuthResult.failure(
        'Offline login not supported. Please connect to the internet.',
      );
    }

    try {
      // 1. Resolve username to email using the app_users table
      final userResponse = await client
          .from('app_users')
          .select('email, id, name, role, is_active, created_at')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (userResponse == null || userResponse['email'] == null) {
        return AuthResult.failure('Invalid username or password.');
      }

      if (userResponse['is_active'] != true) {
        return AuthResult.failure('This account is inactive.');
      }

      final email = userResponse['email'] as String;

      // 2. Authenticate with Supabase Auth
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: cleanPassword,
      );

      if (authResponse.user == null) {
        return AuthResult.failure('Invalid username or password.');
      }

      final supabaseUid = authResponse.user!.id;

      // 3. Fetch app_users by supabase_uid
      final mappedUserResponse = await client
          .from('app_users')
          .select()
          .eq('supabase_uid', supabaseUid)
          .maybeSingle();

      if (mappedUserResponse == null) {
        // Fallback to the one we fetched initially if mapped is not found
        // This is safe since we already validated the email.
        await client
            .from('app_users')
            .update({'supabase_uid': supabaseUid})
            .eq('id', userResponse['id']);
      }

      final finalUserData = mappedUserResponse ?? userResponse;

      if (finalUserData['is_active'] != true) {
        await client.auth.signOut();
        return AuthResult.failure('This account is inactive.');
      }

      final appUser = AppUser(
        id: finalUserData['id'] as String,
        name: finalUserData['name'] as String,
        username: cleanUsername,
        passwordHash: '',
        role: UserRole.fromJson(finalUserData['role'] as String?),
        isActive: finalUserData['is_active'] == true,
        createdAt: finalUserData['created_at'] != null
            ? DateTime.parse(finalUserData['created_at'] as String).toLocal()
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Cache session locally
      await _localCache.cacheSession(appUser);

      return AuthResult.success(appUser);
    } on AuthException catch (_) {
      return AuthResult.failure('Invalid username or password.');
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
    // 1. Fast path: Restore immediately from local cache if available
    final localUser = await _localCache.getCurrentUser();
    if (localUser != null) {
      return localUser;
    }

    // 2. Slow path: No local cache, attempt to restore from Supabase network
    final client = _supabaseService.client;
    if (client != null && client.auth.currentUser != null) {
      final supabaseUid = client.auth.currentUser!.id;

      try {
        final response = await client
            .from('app_users')
            .select()
            .eq('supabase_uid', supabaseUid)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (response != null && response['is_active'] == true) {
          final appUser = AppUser(
            id: response['id'] as String,
            name: response['name'] as String,
            username: response['username'] as String,
            passwordHash: '',
            role: UserRole.fromJson(response['role'] as String?),
            isActive: response['is_active'] == true,
            createdAt: response['created_at'] != null
                ? DateTime.parse(response['created_at'] as String).toLocal()
                : DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Update local cache with fresh data
          await _localCache.cacheSession(appUser);
          return appUser;
        } else if (response != null && response['is_active'] != true) {
          await logout();
          return null;
        }
      } catch (e) {
        // Fallback to local cache if network request fails
      }
    }

    // Fallback to offline Sembast cache
    return await _localCache.getCurrentUser();
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
