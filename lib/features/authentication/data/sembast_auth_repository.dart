import 'package:sembast/sembast.dart';
import '../../../core/database/database_service.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_result.dart';
import '../utils/password_utils.dart';

class SembastAuthRepository implements AuthRepository {
  final DatabaseService _databaseService;

  // Stores
  final _usersStore = stringMapStoreFactory.store('users');
  final _sessionStore = stringMapStoreFactory.store('auth_session');

  // Keys
  static const _sessionKey = 'current_session';

  SembastAuthRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService() {
    _initFuture = _initDefaultUsers();
  }

  Future<Database> get _db async => await _databaseService.database;

  late final Future<void> _initFuture;

  Future<void> _ensureInitialized() => _initFuture;

  Future<void> _initDefaultUsers() async {
    final db = await _db;
    final count = await _usersStore.count(db);

    if (count == 0) {
      final now = DateTime.now();
      
      final defaultUsers = [
        // Admins
        AppUser(
          id: 'ADMIN-001',
          name: 'Anshad',
          username: 'anshad',
          passwordHash: PasswordUtils.hashPassword('anshad123'),
          role: UserRole.admin,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'ADMIN-002',
          name: 'Faris',
          username: 'faris',
          passwordHash: PasswordUtils.hashPassword('faris123'),
          role: UserRole.admin,
          createdAt: now,
          updatedAt: now,
        ),
        // Sales
        AppUser(
          id: 'SALES-001',
          name: 'Ajmal',
          username: 'ajmal',
          passwordHash: PasswordUtils.hashPassword('ajmal123'),
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-002',
          name: 'Harshad',
          username: 'harshad',
          passwordHash: PasswordUtils.hashPassword('harshad123'),
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-003',
          name: 'Nabeel',
          username: 'nabeel',
          passwordHash: PasswordUtils.hashPassword('nabeel123'),
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-004',
          name: 'Naser',
          username: 'naser',
          passwordHash: PasswordUtils.hashPassword('naser123'),
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-005',
          name: 'Shijo',
          username: 'shijo',
          passwordHash: PasswordUtils.hashPassword('shijo123'),
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (var user in defaultUsers) {
        await _usersStore.record(user.id).put(db, user.toJson());
      }
    }
  }

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Invalid username or password.');
    }

    final db = await _db;
    final records = await _usersStore.find(db);

    AppUser? matchedUser;

    for (var record in records) {
      final user = AppUser.fromJson(record.value);
      if (user.username.toLowerCase() == cleanUsername.toLowerCase()) {
        matchedUser = user;
        break;
      }
    }

    if (matchedUser == null ||
        !PasswordUtils.verifyPassword(
          cleanPassword,
          matchedUser.passwordHash,
        )) {
      return AuthResult.failure('Invalid username or password.');
    }

    if (!matchedUser.isActive) {
      return AuthResult.failure('This account is inactive.');
    }

    // Save session
    final sessionData = matchedUser.toJson();
    // Do not store the password hash in the session
    sessionData.remove('passwordHash');
    await _sessionStore.record(_sessionKey).put(db, sessionData);

    return AuthResult.success(matchedUser);
  }

  @override
  Future<void> logout() async {
    await clearRememberedSession();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    await _ensureInitialized();
    final db = await _db;
    final sessionData = await _sessionStore.record(_sessionKey).get(db);

    if (sessionData != null) {
      final user = AppUser.fromJson(sessionData);
      if (user.isActive) {
        return user;
      } else {
        // If the user was deactivated while session was alive
        await clearRememberedSession();
      }
    }
    return null;
  }

  @override
  Future<List<AppUser>> getUsers() async {
    await _ensureInitialized();
    final db = await _db;
    final records = await _usersStore.find(db);
    return records.map((record) => AppUser.fromJson(record.value)).toList();
  }

  @override
  Future<bool> hasRememberedSession() async {
    final user = await getCurrentUser();
    return user != null;
  }

  @override
  Future<void> clearRememberedSession() async {
    final db = await _db;
    await _sessionStore.record(_sessionKey).delete(db);
  }
}
