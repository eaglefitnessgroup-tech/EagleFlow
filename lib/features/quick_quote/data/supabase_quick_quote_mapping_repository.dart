import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/quick_quote_mapping_repository.dart';
import '../domain/quick_quote_product_mapping.dart';
import 'quick_quote_mapping_cache.dart';

class SupabaseQuickQuoteMappingRepository
    implements QuickQuoteMappingRepository {
  SupabaseQuickQuoteMappingRepository({
    required this.localCache,
    required this.supabase,
    String? Function()? sessionKeyProvider,
  }) : _sessionKeyProvider =
           sessionKeyProvider ?? (() => supabase.currentUser?.id);

  final QuickQuoteMappingCache localCache;
  final SupabaseService supabase;
  final String? Function() _sessionKeyProvider;

  int _refreshGeneration = 0;

  @override
  Future<List<QuickQuoteProductMapping>> getAllMappings() => refreshMappings();

  @override
  Future<List<QuickQuoteProductMapping>> refreshMappings() async {
    final generation = ++_refreshGeneration;
    final sessionKey = _sessionKeyProvider();

    if (!isConnectedToServer) {
      return _readCacheOrThrow(
        'The mapping service is offline and no cached mappings are available.',
      );
    }

    try {
      final rows = await fetchMappingsFromServer();
      final mappings = _parseAndValidateRemoteRows(rows);

      if (!_isCurrentRefresh(generation, sessionKey)) {
        return _readCacheOrThrow(
          'A newer mapping refresh or session superseded this request.',
        );
      }

      await localCache.replaceAllMappings(mappings);
      return List.unmodifiable(mappings);
    } catch (error) {
      return _readCacheOrThrow(
        'Remote mappings could not be loaded and no valid cache is available.',
        error,
      );
    }
  }

  @override
  Future<QuickQuoteProductMapping?> getMappingForProduct(
    String productId,
  ) async {
    final mappings = await getAllMappings();
    for (final mapping in mappings) {
      if (mapping.productId == productId) return mapping;
    }
    return null;
  }

  void invalidateSession() {
    _refreshGeneration++;
  }

  List<QuickQuoteProductMapping> _parseAndValidateRemoteRows(
    List<dynamic> rows,
  ) {
    if (rows.isEmpty) {
      throw const FormatException('Remote Quick Quote mappings are empty');
    }

    final productIds = <String>{};
    final mappings = <QuickQuoteProductMapping>[];
    for (final row in rows) {
      if (row is! Map) {
        throw FormatException('Quick Quote mapping row is not an object: $row');
      }
      final mapping = QuickQuoteProductMapping.fromSupabaseRow(
        Map<String, dynamic>.from(row),
      );
      if (!productIds.add(mapping.productId)) {
        throw FormatException(
          'Duplicate Quick Quote product ID: ${mapping.productId}',
        );
      }
      mappings.add(mapping);
    }

    mappings.sort((left, right) => left.productId.compareTo(right.productId));
    return mappings;
  }

  bool _isCurrentRefresh(int generation, String? sessionKey) =>
      generation == _refreshGeneration && sessionKey == _sessionKeyProvider();

  Future<List<QuickQuoteProductMapping>> _readCacheOrThrow(
    String message, [
    Object? cause,
  ]) async {
    try {
      final cached = await localCache.getAllMappings();
      if (cached.isNotEmpty) return cached;
    } catch (cacheError) {
      throw QuickQuoteMappingsUnavailableException(message, cacheError);
    }
    throw QuickQuoteMappingsUnavailableException(message, cause);
  }

  @visibleForTesting
  bool get isConnectedToServer => supabase.isConnected;

  @visibleForTesting
  Future<List<dynamic>> fetchMappingsFromServer() async {
    return await supabase.client!
        .from('quick_quote_product_mappings')
        .select()
        .order('product_id');
  }
}
