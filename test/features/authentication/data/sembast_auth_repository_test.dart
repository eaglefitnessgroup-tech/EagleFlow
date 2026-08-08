import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/authentication/data/sembast_auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';

void main() {
  group('SembastAuthRepository Tests', () {
    late Database db;
    late DatabaseService dbService;
    late SembastAuthRepository repository;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('test_auth.db');
      dbService = DatabaseService()..setDatabaseForTesting(db);
      repository = SembastAuthRepository(databaseService: dbService);
      // Wait for init default users to complete
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Default users are seeded correctly with empty hashes', () async {
      final usersStore = stringMapStoreFactory.store('users');
      final records = await usersStore.find(db);

      expect(records.length, 7);

      final admin = records.firstWhere((r) => r.key == 'ADMIN-001').value;
      final sales = records.firstWhere((r) => r.key == 'SALES-001').value;

      expect(admin['username'], 'anshad');
      expect(sales['username'], 'ajmal');

      expect(admin['passwordHash'], '');
      expect(sales['passwordHash'], '');
    });

    test('2. Admin login success (now fails offline)', () async {
      final result = await repository.login(
        email: 'anshad@eagleflow.com',
        password: 'anshad123',
      );

      expect(result.success, false);
      expect(
        result.message,
        'Offline login not supported. Please connect to the internet.',
      );
    });

    test('3. Salesperson login success (now fails offline)', () async {
      final result = await repository.login(
        email: 'ajmal@eagleflow.com',
        password: 'ajmal123',
      );

      expect(result.success, false);
      expect(
        result.message,
        'Offline login not supported. Please connect to the internet.',
      );
    });

    test(
      '4. Case-insensitive and trimmed username login (now fails offline)',
      () async {
        final result = await repository.login(
          email: '  aNshaD@eagleflow.com  ',
          password: 'anshad123',
        );

        expect(result.success, false);
        expect(
          result.message,
          'Offline login not supported. Please connect to the internet.',
        );
      },
    );

    test('5. Invalid password rejection (now fails offline)', () async {
      final result = await repository.login(
        email: 'anshad@eagleflow.com',
        password: 'wrongpassword',
      );

      expect(result.success, false);
      expect(
        result.message,
        'Offline login not supported. Please connect to the internet.',
      );
    });

    test('6. Inactive user rejection (now fails offline)', () async {
      // Deactivate admin manually
      final usersStore = stringMapStoreFactory.store('users');
      final adminRecord = await usersStore.record('ADMIN-001').get(db);
      final updatedAdmin = Map<String, dynamic>.from(adminRecord!);
      updatedAdmin['isActive'] = false;
      await usersStore.record('ADMIN-001').put(db, updatedAdmin);

      final result = await repository.login(
        email: 'anshad@eagleflow.com',
        password: 'anshad123',
      );

      expect(result.success, false);
      expect(
        result.message,
        'Offline login not supported. Please connect to the internet.',
      );
    });

    test('7. Session caching and retrieval via cacheSession', () async {
      final now = DateTime.now();
      final user = AppUser(
        id: 'ADMIN-001',
        name: 'Anshad',
        username: 'anshad',
        passwordHash: '',
        role: UserRole.admin,
        createdAt: now,
        updatedAt: now,
      );

      await repository.cacheSession(user);

      final hasSession = await repository.hasRememberedSession();
      expect(hasSession, true);

      final cachedUser = await repository.getCurrentUser();
      expect(cachedUser, isNotNull);
      expect(cachedUser!.username, 'anshad');

      // Verify passwordHash is not stored in session
      final sessionStore = stringMapStoreFactory.store('auth_session');
      final sessionData = await sessionStore.record('current_session').get(db);
      expect(sessionData!['passwordHash'], isNull);
    });

    test('8. Logout clears session', () async {
      final now = DateTime.now();
      final user = AppUser(
        id: 'ADMIN-001',
        name: 'Anshad',
        username: 'anshad',
        passwordHash: '',
        role: UserRole.admin,
        createdAt: now,
        updatedAt: now,
      );

      await repository.cacheSession(user);
      expect(await repository.hasRememberedSession(), true);

      await repository.logout();
      expect(await repository.hasRememberedSession(), false);
      expect(await repository.getCurrentUser(), isNull);
    });
  });
}
