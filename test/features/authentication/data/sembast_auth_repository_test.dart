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

    test(
      '1. Default users are seeded correctly and only hashes are stored',
      () async {
        final usersStore = stringMapStoreFactory.store('users');
        final records = await usersStore.find(db);

        expect(records.length, 7);

        final admin = records.firstWhere((r) => r.key == 'ADMIN-001').value;
        final sales = records.firstWhere((r) => r.key == 'SALES-001').value;

        expect(admin['username'], 'anshad');
        expect(sales['username'], 'ajmal');

        expect(admin['passwordHash'], isNot('anshad123'));
        expect(sales['passwordHash'], isNot('ajmal123'));
        expect(admin['password'], isNull);
      },
    );

    test('2. Admin login success', () async {
      final result = await repository.login(
        username: 'anshad',
        password: 'anshad123',
      );

      expect(result.success, true);
      expect(result.user, isNotNull);
      expect(result.user!.role, UserRole.admin);
    });

    test('3. Salesperson login success', () async {
      final result = await repository.login(
        username: 'ajmal',
        password: 'ajmal123',
      );

      expect(result.success, true);
      expect(result.user, isNotNull);
      expect(result.user!.role, UserRole.sales);
    });

    test('4. Case-insensitive and trimmed username login', () async {
      final result = await repository.login(
        username: '  aNshaD  ',
        password: 'anshad123',
      );

      expect(result.success, true);
      expect(result.user!.username, 'anshad');
    });

    test('5. Invalid password rejection', () async {
      final result = await repository.login(
        username: 'anshad',
        password: 'wrongpassword',
      );

      expect(result.success, false);
      expect(result.message, 'Invalid username or password.');
      expect(result.user, isNull);
    });

    test('6. Inactive user rejection', () async {
      // Deactivate admin manually
      final usersStore = stringMapStoreFactory.store('users');
      final adminRecord = await usersStore.record('ADMIN-001').get(db);
      final updatedAdmin = Map<String, dynamic>.from(adminRecord!);
      updatedAdmin['isActive'] = false;
      await usersStore.record('ADMIN-001').put(db, updatedAdmin);

      final result = await repository.login(
        username: 'anshad',
        password: 'anshad123',
      );

      expect(result.success, false);
      expect(result.message, 'This account is inactive.');
      expect(result.user, isNull);
    });

    test('7. Session persistence after successful login', () async {
      await repository.login(username: 'ajmal', password: 'ajmal123');

      final hasSession = await repository.hasRememberedSession();
      expect(hasSession, true);

      final user = await repository.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.username, 'ajmal');

      // Verify passwordHash is not stored in session
      final sessionStore = stringMapStoreFactory.store('auth_session');
      final sessionData = await sessionStore.record('current_session').get(db);
      expect(sessionData!['passwordHash'], isNull);
    });

    test('8. Logout clears session', () async {
      await repository.login(username: 'anshad', password: 'anshad123');
      expect(await repository.hasRememberedSession(), true);

      await repository.logout();
      expect(await repository.hasRememberedSession(), false);
      expect(await repository.getCurrentUser(), isNull);
    });
  });
}
