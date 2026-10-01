import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickQuoteProductMapping', () {
    test('maps every database field into typed values', () {
      final mapping = QuickQuoteProductMapping.fromSupabaseRow(
        _eligibleStrengthRow(),
      );

      expect(mapping.productId, 'product-1');
      expect(mapping.status, QuickQuoteMappingStatus.eligible);
      expect(mapping.section, QuickQuoteSection.strength);
      expect(mapping.roleKey, 'chest_press');
      expect(mapping.strengthArea, QuickQuoteStrengthArea.chest);
      expect(mapping.loadType, QuickQuoteLoadType.pinLoaded);
      expect(mapping.movementKey, 'horizontal_press');
      expect(mapping.familyKey, 'active');
      expect(mapping.plateWeightKg, isNull);
      expect(mapping.stationCount, isNull);
      expect(mapping.selectionPriority, 10);
      expect(mapping.upgradePriority, 20);
      expect(mapping.updatedAt, DateTime.parse('2026-10-01T08:00:00Z'));
      expect(mapping.isEligible, isTrue);

      final plate = QuickQuoteProductMapping.fromSupabaseRow(
        _eligibleWeightPlateRow(),
      );
      final multiStation = QuickQuoteProductMapping.fromSupabaseRow(
        _eligibleMultiStationRow(),
      );
      expect(plate.plateWeightKg, 12.5);
      expect(multiStation.stationCount, 2);
    });

    test('parses manual excluded mappings with nullable classification', () {
      final mapping = QuickQuoteProductMapping.fromSupabaseRow(
        _manualExcludedRow(),
      );

      expect(mapping.status, QuickQuoteMappingStatus.manualExcluded);
      expect(mapping.isEligible, isFalse);
      expect(mapping.section, isNull);
      expect(mapping.roleKey, isNull);
      expect(mapping.strengthArea, isNull);
      expect(mapping.loadType, isNull);
      expect(mapping.movementKey, isNull);
      expect(mapping.familyKey, isNull);
      expect(mapping.plateWeightKg, isNull);
      expect(mapping.stationCount, isNull);
    });

    test('round-trips nullable fields through cache serialization', () {
      final original = QuickQuoteProductMapping.fromSupabaseRow(
        _manualExcludedRow(),
      );

      final restored = QuickQuoteProductMapping.fromCacheJson(
        original.toCacheJson(),
      );

      expect(restored.toCacheJson(), original.toCacheJson());
    });

    test('rejects unknown database enum values', () {
      final invalidStatus = _eligibleStrengthRow()..['status'] = 'maybe';
      final invalidSection = _eligibleStrengthRow()..['section'] = 'spa';
      final invalidLoad = _eligibleStrengthRow()..['load_type'] = 'gravity';

      expect(
        () => QuickQuoteProductMapping.fromSupabaseRow(invalidStatus),
        throwsFormatException,
      );
      expect(
        () => QuickQuoteProductMapping.fromSupabaseRow(invalidSection),
        throwsFormatException,
      );
      expect(
        () => QuickQuoteProductMapping.fromSupabaseRow(invalidLoad),
        throwsFormatException,
      );
    });

    test('rejects malformed eligible mappings instead of downgrading them', () {
      final row = _eligibleStrengthRow()..['role_key'] = null;

      expect(
        () => QuickQuoteProductMapping.fromSupabaseRow(row),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _eligibleStrengthRow() => <String, dynamic>{
  'product_id': 'product-1',
  'status': 'eligible',
  'section': 'strength',
  'role_key': 'chest_press',
  'strength_area': 'chest',
  'load_type': 'pin_loaded',
  'movement_key': 'horizontal_press',
  'family_key': 'active',
  'plate_weight_kg': null,
  'station_count': null,
  'selection_priority': 10,
  'upgrade_priority': 20,
  'updated_at': '2026-10-01T08:00:00Z',
};

Map<String, dynamic> _eligibleWeightPlateRow() => <String, dynamic>{
  ..._eligibleStrengthRow(),
  'product_id': 'product-plate',
  'section': 'weight_plate',
  'role_key': 'weight_plate',
  'strength_area': null,
  'load_type': null,
  'plate_weight_kg': 12.5,
};

Map<String, dynamic> _eligibleMultiStationRow() => <String, dynamic>{
  ..._eligibleStrengthRow(),
  'product_id': 'product-multi',
  'section': 'multifunction',
  'role_key': 'multi_station',
  'strength_area': null,
  'load_type': null,
  'station_count': 2,
};

Map<String, dynamic> _manualExcludedRow() => <String, dynamic>{
  'product_id': 'product-2',
  'status': 'manual_excluded',
  'section': null,
  'role_key': null,
  'strength_area': null,
  'load_type': null,
  'movement_key': null,
  'family_key': null,
  'plate_weight_kg': null,
  'station_count': null,
  'selection_priority': 0,
  'upgrade_priority': 0,
  'updated_at': '2026-10-01T08:00:00Z',
};
