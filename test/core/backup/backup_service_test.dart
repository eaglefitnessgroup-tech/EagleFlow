import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:path/path.dart' as p;
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/backup/backup_models.dart';
import 'package:eagleflow/core/backup/backup_service.dart';

void main() {
  late Database db;
  late BackupService backupService;
  late Directory tempDir;
  late String backupFilePath;

  setUp(() async {
    final dbName = 'test_backup_${DateTime.now().millisecondsSinceEpoch}.db';
    db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    backupService = BackupService();

    // Create a temporary directory for backups
    tempDir = await Directory.systemTemp.createTemp('eagleflow_backup_test');
    backupFilePath = p.join(tempDir.path, 'test_backup.json');

    // Populate some initial test data
    final usersStore = stringMapStoreFactory.store('users');
    final productsStore = stringMapStoreFactory.store('products');
    final stockStore = stringMapStoreFactory.store('stock_movements_store');

    await usersStore.record('user1').put(db, {
      'name': 'Alice',
      'role': 'admin',
      'passwordHash': 'secret_hash_1',
      'auth_uid': 'uid_1',
    });
    await productsStore.record('prod1').put(db, {'name': 'Product A'});
    await stockStore.record('stock1').put(db, {'qty': 10});
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'BackupService creates a valid backup file with correct metadata and counts',
    () async {
      final result = await backupService.createBackup(backupFilePath);
      expect(result.isSuccess, true);

      final file = File(backupFilePath);
      expect(file.existsSync(), true);

      final content =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final meta = content['metadata'];

      expect(meta['recordCounts']['users'], 1);
      expect(meta['recordCounts']['products'], 1);
      expect(meta['recordCounts']['stock_movements_store'], 1);
      expect(meta['schemaVersion'], 1);
    },
  );

  test('Checksum validation fails if payload is altered', () async {
    await backupService.createBackup(backupFilePath);

    final file = File(backupFilePath);
    final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    // Alter the payload
    content['payload']['users']['user1']['name'] = 'Hacked';
    file.writeAsStringSync(jsonEncode(content));

    final preview = await backupService.previewRestore(backupFilePath);
    expect(preview.isValid, false);
    expect(preview.errorMessage, contains('checksum mismatch'));
  });

  test('Preview rejects unsupported schema versions', () async {
    await backupService.createBackup(backupFilePath);

    final file = File(backupFilePath);
    final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    content['metadata']['schemaVersion'] = 999;
    // Recompute checksum for altered metadata is not needed since checksum only hashes payload.
    file.writeAsStringSync(jsonEncode(content));

    final preview = await backupService.previewRestore(backupFilePath);
    expect(preview.isValid, false);
    expect(preview.errorMessage, contains('Unsupported schema version'));
  });

  test(
    'Successful atomic restore preserves IDs and does not duplicate',
    () async {
      await backupService.createBackup(backupFilePath);

      // Add some new local data to see if it gets merged properly
      final usersStore = stringMapStoreFactory.store('users');
      await usersStore.record('user2').put(db, {
        'name': 'Bob',
        'passwordHash': 'bob_hash',
      });

      // Alter user1
      await usersStore.record('user1').put(db, {
        'name': 'Changed',
        'role': 'user',
        'passwordHash': 'secret_hash_1',
      });

      // Execute restore
      final restoreResult = await backupService.executeRestore(backupFilePath);
      expect(restoreResult.isSuccess, true);

      // Verify
      final user1 = await usersStore.record('user1').get(db);
      expect(user1?['name'], 'Alice'); // Restored back to Alice
      expect(user1?['role'], 'admin');

      final user2 = await usersStore.record('user2').get(db);
      expect(user2?['name'], 'Bob'); // Should still exist (we only upsert)

      // Verify duplicate-safe (only 2 users)
      final allUsers = await usersStore.find(db);
      expect(allUsers.length, 2);

      // Check if pre-restore backup was created
      final files = tempDir.listSync();
      final preRestoreFiles = files.where(
        (f) => p.basename(f.path).startsWith('pre_restore_'),
      );
      expect(preRestoreFiles.length, 1);
    },
  );

  test('Backup JSON contains no passwordHash or auth_uid', () async {
    await backupService.createBackup(backupFilePath);

    final file = File(backupFilePath);
    final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final users = content['payload']['users'] as Map<String, dynamic>;
    expect(users['user1'].containsKey('passwordHash'), false);
    expect(users['user1'].containsKey('auth_uid'), false);
  });

  test('Restore preserves existing passwordHash', () async {
    await backupService.createBackup(backupFilePath);

    final usersStore = stringMapStoreFactory.store('users');
    // Change password hash locally
    await usersStore.record('user1').put(db, {
      'name': 'Changed',
      'passwordHash': 'new_hash_123',
      'auth_uid': 'new_uid',
    });

    final restoreResult = await backupService.executeRestore(backupFilePath);
    expect(restoreResult.isSuccess, true);

    final user1 = await usersStore.record('user1').get(db);
    expect(user1?['name'], 'Alice'); // Restored
    expect(user1?['passwordHash'], 'new_hash_123'); // Preserved
    expect(user1?['auth_uid'], 'new_uid'); // Preserved
  });

  test(
    'Restore skips creating missing users to prevent unusable accounts',
    () async {
      // Backup contains user1
      await backupService.createBackup(backupFilePath);

      final usersStore = stringMapStoreFactory.store('users');
      // Delete user1 locally
      await usersStore.record('user1').delete(db);

      final restoreResult = await backupService.executeRestore(backupFilePath);
      expect(restoreResult.isSuccess, true);

      // user1 should still be deleted because we skip missing users
      final user1 = await usersStore.record('user1').get(db);
      expect(user1, null);
    },
  );

  test(
    'Excludes sessions and secrets implicitly by only targeting specific stores',
    () async {
      // Add auth_session data
      final sessionStore = stringMapStoreFactory.store('auth_session');
      await sessionStore.record('current').put(db, {'token': 'secret123'});

      await backupService.createBackup(backupFilePath);

      final file = File(backupFilePath);
      final content =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(content['payload'].containsKey('auth_session'), false);
      expect(content['payload'].containsKey('users'), true);
    },
  );
}
