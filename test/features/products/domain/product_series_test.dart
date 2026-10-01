import 'package:eagleflow/features/products/domain/product_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shared Premier series mapping', () {
    test('preserves every approved visible series label', () {
      expect(premierSeriesForPrefix('APN')?.label, 'Active Series (Pin)');
      expect(premierSeriesForPrefix('APL')?.label, 'Active Series (PL)');
      expect(premierSeriesForPrefix('PXN')?.label, 'Torque Series (Pin)');
      expect(premierSeriesForPrefix('PXL')?.label, 'Torque Series (PL)');
      expect(premierSeriesForPrefix('EPN')?.label, 'Elite Series (Pin)');
    });

    test('keeps the visible Product Picker series list unchanged', () {
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

    test('does not infer unknown series or load types', () {
      expect(premierSeriesForPrefix('EPL'), isNull);
      expect(premierSeriesForPrefix('UNKNOWN'), isNull);
      expect(confirmedProductLoadTypeForPrefix('EPL'), isNull);
      expect(confirmedProductLoadTypeForCode('UNKNOWN1'), isNull);
    });

    test('exposes TQN and TQL load types without visible series chips', () {
      expect(
        confirmedProductLoadTypeForPrefix('TQN'),
        pinLoadedProductLoadType,
      );
      expect(
        confirmedProductLoadTypeForCode('tql45'),
        plateLoadedProductLoadType,
      );
      expect(premierSeriesForPrefix('TQN'), isNull);
      expect(premierSeriesForPrefix('TQL'), isNull);
      expect(
        derivePremierSeriesOptions([
          'APN39',
          'TQN39',
          'TQL45',
        ]).map((series) => series.prefix),
        ['APN'],
      );
    });
  });
}
