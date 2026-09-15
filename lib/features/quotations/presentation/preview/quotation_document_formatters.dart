class QuotationDocumentFormatters {
  QuotationDocumentFormatters._();

  static String formatCurrency(double amount) {
    String priceStr = amount.toStringAsFixed(2);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

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
    final String firstGroup = parts.sublist(0, midpoint).map((p) => p.trim()).join(' | ');
    final String secondGroup = parts.sublist(midpoint).map((p) => p.trim()).join(' | ');

    return '$firstGroup\n$secondGroup';
  }
}
