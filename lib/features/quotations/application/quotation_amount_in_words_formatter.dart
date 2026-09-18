class QuotationAmountInWordsFormatter {
  QuotationAmountInWordsFormatter._();

  static const List<String> _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static const List<String> _scales = [
    '',
    'Thousand',
    'Million',
    'Billion',
    'Trillion',
    'Quadrillion',
  ];

  static String format(double amount) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be a finite, non-negative value.',
      );
    }

    final monetaryParts = amount.toStringAsFixed(2).split('.');
    final dirhams = int.parse(monetaryParts[0]);
    final fils = int.parse(monetaryParts[1]);

    final buffer = StringBuffer()
      ..write(_integerToWords(dirhams))
      ..write(dirhams == 1 ? ' Dirham' : ' Dirhams');

    if (fils > 0) {
      buffer
        ..write(' and ')
        ..write(_integerToWords(fils))
        ..write(fils == 1 ? ' Fil' : ' Fils');
    }

    buffer.write(' Only');
    return buffer.toString();
  }

  static String _integerToWords(int value) {
    if (value == 0) return 'Zero';

    final parts = <String>[];
    var remaining = value;
    var scaleIndex = 0;

    while (remaining > 0) {
      final group = remaining % 1000;
      if (group > 0) {
        final scale = _scales[scaleIndex];
        final groupWords = _underOneThousand(group);
        parts.insert(0, scale.isEmpty ? groupWords : '$groupWords $scale');
      }
      remaining ~/= 1000;
      scaleIndex++;
    }

    return parts.join(' ');
  }

  static String _underOneThousand(int value) {
    final parts = <String>[];
    var remaining = value;

    if (remaining >= 100) {
      parts.add('${_ones[remaining ~/ 100]} Hundred');
      remaining %= 100;
    }

    if (remaining >= 20) {
      final tensWord = _tens[remaining ~/ 10];
      final onesValue = remaining % 10;
      parts.add(onesValue == 0 ? tensWord : '$tensWord-${_ones[onesValue]}');
    } else if (remaining > 0) {
      parts.add(_ones[remaining]);
    }

    return parts.join(' ');
  }
}
