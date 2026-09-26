enum ProductCondition {
  newProduct('new', 'New'),
  used('used', 'Used'),
  refurbished('refurbished', 'Refurbished'),
  display('display', 'Display');

  const ProductCondition(this.persistedValue, this.displayLabel);

  final String persistedValue;
  final String displayLabel;

  static ProductCondition? tryParse(Object? value) {
    if (value is! String) return null;

    final normalized = value.trim().toLowerCase();
    for (final condition in ProductCondition.values) {
      if (condition.persistedValue == normalized) return condition;
    }
    return null;
  }
}
