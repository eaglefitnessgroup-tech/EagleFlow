import 'quick_quote_product_mapping.dart';

abstract interface class QuickQuoteMappingRepository {
  Future<List<QuickQuoteProductMapping>> getAllMappings();

  Future<List<QuickQuoteProductMapping>> refreshMappings();

  Future<QuickQuoteProductMapping?> getMappingForProduct(String productId);
}

class QuickQuoteMappingsUnavailableException implements Exception {
  const QuickQuoteMappingsUnavailableException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'Quick Quote mappings unavailable: $message';
}
