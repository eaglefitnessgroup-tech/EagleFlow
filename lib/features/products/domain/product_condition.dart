enum ProductCondition {
  newProduct('new', 'New'),
  used('used', 'Used'),
  refurbished('refurbished', 'Refurbished'),
  display('display', 'Display');

  const ProductCondition(this.persistedValue, this.displayLabel);

  final String persistedValue;
  final String displayLabel;

  static String get allowedValuesText {
    final labels = ProductCondition.values
        .map((condition) => condition.displayLabel)
        .toList(growable: false);
    return '${labels.take(labels.length - 1).join(', ')}, or ${labels.last}';
  }

  static String get invalidValueMessage =>
      'Invalid Condition. Use $allowedValuesText.';

  static ProductCondition? tryParse(Object? value) {
    if (value is! String) return null;

    final normalized = value.trim().toLowerCase();
    for (final condition in ProductCondition.values) {
      if (condition.persistedValue == normalized) return condition;
    }
    return null;
  }
}
