import '../domain/quick_quote_product_mapping.dart';

abstract interface class QuickQuoteMappingCache {
  Future<List<QuickQuoteProductMapping>> getAllMappings();

  Future<QuickQuoteProductMapping?> getMappingForProduct(String productId);

  Future<void> replaceAllMappings(List<QuickQuoteProductMapping> mappings);
}
