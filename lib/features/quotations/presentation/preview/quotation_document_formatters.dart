import '../../../products/domain/product_condition.dart';

class QuotationDocumentFormatters {
  QuotationDocumentFormatters._();

  static const String _separator = ' • ';

  static String formatProductMetadata(String? productCode, String brand) {
    final displayedCode = productCode?.isNotEmpty == true ? productCode! : '—';
    final displayedBrand = brand.isNotEmpty ? brand : '—';
    return 'CODE: ${displayedCode.toUpperCase()} | '
        'BRAND: ${displayedBrand.toUpperCase()}';
  }

  static String formatCompactProductMetadata(
    String? productCode,
    String brand,
  ) {
    final values = <String>[
      if (productCode?.trim().isNotEmpty == true)
        productCode!.trim().toUpperCase(),
      if (brand.trim().isNotEmpty) brand.trim().toUpperCase(),
    ];
    return values.isEmpty ? '—' : values.join(_separator);
  }

  static String formatCurrency(double amount) {
    String priceStr = amount.toStringAsFixed(2);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  static String formatDiscount(double discount) {
    if (discount <= 0) return '—';
    final value = discount == discount.roundToDouble()
        ? discount.toStringAsFixed(0)
        : discount
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '$value%';
  }

  static String? formatProductCondition(ProductCondition? condition) {
    if (condition == null) return null;
    return 'CONDITION: ${condition.displayLabel.toUpperCase()}';
  }

  static String formatProductConditionValue(ProductCondition? condition) =>
      condition?.displayLabel.toUpperCase() ?? '—';

  static String formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  static String? formatSpecification(String? description) {
    if (description == null || description.trim().isEmpty) return description;

    if (description.contains('\n')) {
      return description;
    }

    final parts = description.split('|');
    if (parts.length <= 2) {
      return description;
    }

    final int midpoint = (parts.length / 2).ceil();
    final String firstGroup = parts
        .sublist(0, midpoint)
        .map((p) => p.trim())
        .join(' | ');
    final String secondGroup = parts
        .sublist(midpoint)
        .map((p) => p.trim())
        .join(' | ');

    return '$firstGroup\n$secondGroup';
  }

  static String? formatCompactSpecification(String? description) {
    if (description == null || description.trim().isEmpty) return description;

    return description
        .split(RegExp(r'\s*(?:\r?\n|\|)\s*'))
        .where((part) => part.isNotEmpty)
        .join(_separator);
  }
}
