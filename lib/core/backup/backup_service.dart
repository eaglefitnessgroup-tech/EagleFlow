import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import '../database/database_service.dart';
import 'backup_models.dart';
import 'package:path/path.dart' as p;

class BackupService {
  final DatabaseService _dbService;

  BackupService({DatabaseService? dbService})
    : _dbService = dbService ?? DatabaseService();

  // Stores to include in the backup
  final _usersStore = stringMapStoreFactory.store('users');
  final _productsStore = stringMapStoreFactory.store('products');
  final _stockStore = stringMapStoreFactory.store('stock_movements_store');
  final _quotationsStore = stringMapStoreFactory.store('quotations');
  final _metadataStore = stringMapStoreFactory.store('metadata');

  static const int _currentSchemaVersion = 1;
  static const String _appVersion = '0.7.0'; // Example version based on phase

  /// Creates a backup JSON file at the specified absolute path.
  Future<BackupResult> createBackup(String absolutePath) async {
    try {
      final db = await _dbService.database;

      final users = await _usersStore.find(db);
      final products = await _productsStore.find(db);
      final stockMovements = await _stockStore.find(db);
      final quotations = await _quotationsStore.find(db);
      final metadata = await _metadataStore.find(db);

      final payload = {
        'users': _sanitizeUsers(users),
        'products': _recordsToMap(products),
        'stock_movements_store': _recordsToMap(stockMovements),
        'quotations': _recordsToMap(quotations),
        'metadata': _recordsToMap(metadata),
      };

      final recordCounts = {
        'users': users.length,
        'products': products.length,
        'stock_movements_store': stockMovements.length,
        'quotations': quotations.length,
        'metadata': metadata.length,
      };

      final payloadJson = jsonEncode(payload);
      final checksum = BackupMetadata.computeChecksum(payloadJson);

      final backupMeta = BackupMetadata(
        schemaVersion: _currentSchemaVersion,
        createdAt: DateTime.now().toIso8601String(),
        appVersion: _appVersion,
        recordCounts: recordCounts,
        checksum: checksum,
      );

      final backupData = {'metadata': backupMeta.toJson(), 'payload': payload};

      final file = File(absolutePath);
      // Ensure parent directory exists
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      await file.writeAsString(jsonEncode(backupData));
      return BackupResult.success(absolutePath);
    } catch (e) {
      debugPrint('Backup failed: $e');
      return BackupResult.failure(e.toString());
    }
  }

  /// Previews a restore operation to validate the backup file without modifying data.
  Future<RestorePreview> previewRestore(String absolutePath) async {
    try {
      final file = File(absolutePath);
      if (!await file.exists()) {
        return RestorePreview.failure('Backup file not found.');
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!data.containsKey('metadata') || !data.containsKey('payload')) {
        return RestorePreview.failure('Invalid backup file format.');
      }

      final meta = BackupMetadata.fromJson(data['metadata']);
      final payloadMap = data['payload'] as Map<String, dynamic>;
      final payloadJson = jsonEncode(payloadMap);

      if (meta.schemaVersion > _currentSchemaVersion) {
        return RestorePreview.failure(
          'Unsupported schema version: ${meta.schemaVersion}. Please update the app.',
        );
      }

      if (!meta.verifyChecksum(payloadJson)) {
        return RestorePreview.failure(
          'Backup file is corrupted (checksum mismatch).',
        );
      }

      return RestorePreview.success(
        meta.schemaVersion,
        meta.recordCounts,
        payloadJson,
        payloadMap,
      );
    } catch (e) {
      return RestorePreview.failure('Failed to read backup: $e');
    }
  }

  /// Executes the actual restore process. Requires explicit confirmation and atomic transaction.
  Future<RestoreResult> executeRestore(String absolutePath) async {
    try {
      final preview = await previewRestore(absolutePath);
      if (!preview.isValid || preview.parsedPayload == null) {
        return RestoreResult.failure(preview.errorMessage ?? 'Invalid backup.');
      }

      // Create an automatic pre-restore backup
      final file = File(absolutePath);
      final backupDir = file.parent.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final preRestorePath = p.join(backupDir, 'pre_restore_$timestamp.json');
      final preBackupResult = await createBackup(preRestorePath);
      if (!preBackupResult.isSuccess) {
        return RestoreResult.failure('Failed to create pre-restore backup.');
      }

      final db = await _dbService.database;
      final payload = preview.parsedPayload!;

      await db.transaction((txn) async {
        await _restoreStore(_usersStore, payload['users'], txn);
        await _restoreStore(_productsStore, payload['products'], txn);
        await _restoreStore(_stockStore, payload['stock_movements_store'], txn);
        await _restoreStore(_quotationsStore, payload['quotations'], txn);
        await _restoreStore(_metadataStore, payload['metadata'], txn);
      });

      return RestoreResult.success();
    } catch (e) {
      debugPrint('Restore failed: $e');
      return RestoreResult.failure(e.toString());
    }
  }

  Map<String, dynamic> _recordsToMap(
    List<RecordSnapshot<String, dynamic>> records,
  ) {
    return {for (var r in records) r.key: r.value};
  }

  Map<String, dynamic> _sanitizeUsers(
    List<RecordSnapshot<String, dynamic>> records,
  ) {
    final result = <String, dynamic>{};
    for (var r in records) {
      final map = Map<String, dynamic>.from(r.value);
      map.remove('passwordHash');
      map.remove('supabase_uid'); // Supabase UID if present
      result[r.key] = map;
    }
    return result;
  }

  Future<void> _restoreStore(
    StoreRef<String, dynamic> store,
    dynamic storeData,
    Transaction txn,
  ) async {
    if (storeData == null || storeData is! Map) return;
    final map = storeData as Map<String, dynamic>;

    // Handle user specifically to prevent overwriting secrets or creating broken users
    if (store.name == 'users') {
      for (final entry in map.entries) {
        final existing =
            await store.record(entry.key).get(txn) as Map<String, dynamic>?;
        if (existing == null) {
          debugPrint(
            'Skipping missing user ${entry.key} to avoid blank password hash.',
          );
          continue;
        }

        final updatedData = Map<String, dynamic>.from(entry.value as Map);
        // Preserve existing secrets
        if (existing.containsKey('passwordHash')) {
          updatedData['passwordHash'] = existing['passwordHash'];
        }
        if (existing.containsKey('supabase_uid')) {
          updatedData['supabase_uid'] = existing['supabase_uid'];
        }

        await store.record(entry.key).put(txn, updatedData);
      }
      return;
    }

    // Iterate over the keys and upsert, preserving existing IDs
    for (final entry in map.entries) {
      await store.record(entry.key).put(txn, entry.value);
    }
  }
}
