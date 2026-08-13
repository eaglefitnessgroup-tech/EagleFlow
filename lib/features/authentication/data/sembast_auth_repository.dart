import 'package:sembast/sembast.dart';
import '../../../core/database/database_service.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_result.dart';

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
          passwordHash: '',
          role: UserRole.admin,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'ADMIN-002',
          name: 'Faris',
          username: 'faris',
          passwordHash: '',
          role: UserRole.admin,
          createdAt: now,
          updatedAt: now,
        ),
        // Sales
        AppUser(
          id: 'SALES-001',
          name: 'Ajmal',
          username: 'ajmal',
          passwordHash: '',
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-002',
          name: 'Harshad',
          username: 'harshad',
          passwordHash: '',
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-003',
          name: 'Nabeel',
          username: 'nabeel',
          passwordHash: '',
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-004',
          name: 'Naser',
          username: 'naser',
          passwordHash: '',
          role: UserRole.sales,
          createdAt: now,
          updatedAt: now,
        ),
        AppUser(
          id: 'SALES-005',
          name: 'Shijo',
          username: 'shijo',
          passwordHash: '',
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
    required String email,
    required String password,
  }) async {
    // SembastAuthRepository no longer handles credentials.
    return AuthResult.failure(
      'Offline login not supported. Please connect to the internet.',
    );
  }

  /// Caches the authenticated user session locally for offline restarts.
  Future<void> cacheSession(AppUser user) async {
    final db = await _db;
    final sessionData = user.toJson();
    sessionData.remove('passwordHash');
    await _sessionStore.record(_sessionKey).put(db, sessionData);
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
