class ProductSeriesDefinition {
  final String prefix;
  final String label;

  const ProductSeriesDefinition({required this.prefix, required this.label});
}

const List<ProductSeriesDefinition> premierSeriesDefinitions = [
  ProductSeriesDefinition(prefix: 'APN', label: 'Active Series (Pin)'),
  ProductSeriesDefinition(prefix: 'APL', label: 'Active Series (PL)'),
  ProductSeriesDefinition(prefix: 'PXN', label: 'Torque Series (Pin)'),
  ProductSeriesDefinition(prefix: 'PXL', label: 'Torque Series (PL)'),
  ProductSeriesDefinition(prefix: 'EPN', label: 'Elite Series (Pin)'),
];

String? deriveProductSeriesPrefix(String productCode) {
  final match = RegExp(r'^[A-Za-z]+').firstMatch(productCode.trim());
  return match?.group(0)?.toUpperCase();
}

ProductSeriesDefinition? premierSeriesForPrefix(String? prefix) {
  if (prefix == null) return null;

  final normalizedPrefix = prefix.toUpperCase();
  for (final series in premierSeriesDefinitions) {
    if (series.prefix == normalizedPrefix) return series;
  }
  return null;
}

List<ProductSeriesDefinition> derivePremierSeriesOptions(
  Iterable<String> productCodes,
) {
  final availablePrefixes = productCodes
      .map(deriveProductSeriesPrefix)
      .whereType<String>()
      .toSet();

  return premierSeriesDefinitions
      .where((series) => availablePrefixes.contains(series.prefix))
      .toList(growable: false);
}
