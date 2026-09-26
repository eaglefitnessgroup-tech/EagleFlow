import 'package:eagleflow/features/quotations/presentation/widgets/create/product_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveProductSeriesPrefix', () {
    test('extracts and normalizes a leading alphabetic prefix', () {
      expect(deriveProductSeriesPrefix('APN39'), 'APN');
      expect(deriveProductSeriesPrefix('APL12'), 'APL');
      expect(deriveProductSeriesPrefix('pxn20'), 'PXN');
      expect(deriveProductSeriesPrefix(' PXL-08 '), 'PXL');
      expect(deriveProductSeriesPrefix('ePn14'), 'EPN');
    });

    test('returns null when the code has no leading alphabetic prefix', () {
      expect(deriveProductSeriesPrefix(''), isNull);
      expect(deriveProductSeriesPrefix('  '), isNull);
      expect(deriveProductSeriesPrefix('123APN'), isNull);
      expect(deriveProductSeriesPrefix('-APN39'), isNull);
    });
  });

  group('Premier series mapping', () {
    test('contains exactly the five approved prefix and label mappings', () {
      expect(
        premierSeriesDefinitions
            .map((series) => '${series.prefix}:${series.label}')
            .toList(),
        [
          'APN:Active Series (Pin)',
          'APL:Active Series (PL)',
          'PXN:Torque Series (Pin)',
          'PXL:Torque Series (PL)',
          'EPN:Elite Series (Pin)',
        ],
      );
    });

    test('does not infer unapproved or unknown mappings', () {
      expect(premierSeriesForPrefix('EPL'), isNull);
      expect(premierSeriesForPrefix('TQL'), isNull);
      expect(premierSeriesForPrefix('TQN'), isNull);
      expect(premierSeriesForPrefix('UNKNOWN'), isNull);
    });

    test('derives options only for approved prefixes present in products', () {
      final options = derivePremierSeriesOptions([
        'APN39',
        'apn40',
        'PXL-08',
        'TQL25',
        'UNKNOWN1',
      ]);

      expect(options.map((series) => series.prefix), ['APN', 'PXL']);
    });
  });
}
