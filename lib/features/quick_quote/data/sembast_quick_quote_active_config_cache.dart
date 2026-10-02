import 'package:sembast/sembast.dart';

import '../../../core/database/database_service.dart';
import '../domain/quick_quote_active_configuration.dart';
import '../domain/quick_quote_active_config_repository.dart';
import 'quick_quote_active_config_cache.dart';

class SembastQuickQuoteActiveConfigCache
    implements QuickQuoteActiveConfigCache {
  SembastQuickQuoteActiveConfigCache({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  static const _recordKey = 'active';

  final DatabaseService _databaseService;
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('quick_quote_active_configuration_cache');

  Future<Database> get _database async => _databaseService.database;

  @override
  Future<QuickQuoteActiveConfiguration?> getConfiguration() async {
    final value = await _store.record(_recordKey).get(await _database);
    if (value == null) return null;
    return QuickQuoteActiveConfiguration.fromCacheJson(value);
  }

  @override
  Future<void> replaceConfiguration(
    QuickQuoteActiveConfiguration configuration, {
    bool Function()? canCommit,
  }) async {
    configuration.validate();
    final serialized = configuration.toCacheJson();
    final database = await _database;
    await database.transaction((transaction) async {
      if (canCommit != null && !canCommit()) {
        throw const QuickQuoteActiveConfigStaleSessionException();
      }
      await _store.record(_recordKey).put(transaction, serialized);
      if (canCommit != null && !canCommit()) {
        throw const QuickQuoteActiveConfigStaleSessionException();
      }
    });
  }
}
