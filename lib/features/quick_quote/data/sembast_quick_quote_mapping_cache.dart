import 'package:sembast/sembast.dart';

import '../../../core/database/database_service.dart';
import '../domain/quick_quote_product_mapping.dart';
import 'quick_quote_mapping_cache.dart';

class SembastQuickQuoteMappingCache implements QuickQuoteMappingCache {
  SembastQuickQuoteMappingCache({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('quick_quote_product_mappings_cache');

  Future<Database> get _database async => _databaseService.database;

  @override
  Future<List<QuickQuoteProductMapping>> getAllMappings() async {
    final records = await _store.find(await _database);
    final mappings =
        records
            .map(
              (record) => QuickQuoteProductMapping.fromCacheJson(record.value),
            )
            .toList()
          ..sort((left, right) => left.productId.compareTo(right.productId));
    _ensureUniqueProductIds(mappings);
    return List.unmodifiable(mappings);
  }

  @override
  Future<QuickQuoteProductMapping?> getMappingForProduct(
    String productId,
  ) async {
    final value = await _store.record(productId).get(await _database);
    return value == null ? null : QuickQuoteProductMapping.fromCacheJson(value);
  }

  @override
  Future<void> replaceAllMappings(
    List<QuickQuoteProductMapping> mappings,
  ) async {
    if (mappings.isEmpty) {
      throw const FormatException('Quick Quote mapping cache cannot be empty');
    }
    _ensureUniqueProductIds(mappings);
    final serialized = <String, Map<String, Object?>>{
      for (final mapping in mappings) mapping.productId: mapping.toCacheJson(),
    };

    final database = await _database;
    await database.transaction((transaction) async {
      await _store.delete(transaction);
      for (final entry in serialized.entries) {
        await _store.record(entry.key).put(transaction, entry.value);
      }
    });
  }

  void _ensureUniqueProductIds(List<QuickQuoteProductMapping> mappings) {
    final productIds = <String>{};
    for (final mapping in mappings) {
      mapping.validate();
      if (!productIds.add(mapping.productId)) {
        throw FormatException(
          'Duplicate Quick Quote product ID: ${mapping.productId}',
        );
      }
    }
  }
}
