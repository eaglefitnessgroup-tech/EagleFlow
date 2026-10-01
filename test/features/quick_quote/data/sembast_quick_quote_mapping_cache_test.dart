import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/quick_quote/data/sembast_quick_quote_mapping_cache.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late SembastQuickQuoteMappingCache cache;

  setUp(() async {
    database = await databaseFactoryMemory.openDatabase(
      'quick_quote_cache_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);
    cache = SembastQuickQuoteMappingCache();
  });

  tearDown(() async {
    await database.close();
  });

  test('atomically replaces the full cache and removes stale rows', () async {
    await cache.replaceAllMappings([
      _mapping('product-a'),
      _mapping('product-stale'),
    ]);

    await cache.replaceAllMappings([_mapping('product-b')]);

    final mappings = await cache.getAllMappings();
    expect(mappings.map((mapping) => mapping.productId), ['product-b']);
    expect(await cache.getMappingForProduct('product-stale'), isNull);
  });

  test('failed replacement preserves the previous good cache', () async {
    await cache.replaceAllMappings([_mapping('product-good')]);
    final invalid = QuickQuoteProductMapping(
      productId: 'product-invalid',
      status: QuickQuoteMappingStatus.eligible,
      section: QuickQuoteSection.cardio,
      roleKey: 'treadmill',
      strengthArea: null,
      loadType: null,
      movementKey: null,
      familyKey: null,
      plateWeightKg: null,
      stationCount: null,
      selectionPriority: -1,
      upgradePriority: 0,
      updatedAt: DateTime.utc(2026, 10),
    );

    await expectLater(
      cache.replaceAllMappings([invalid]),
      throwsFormatException,
    );

    expect((await cache.getAllMappings()).single.productId, 'product-good');
  });

  test('lookup is deterministic and missing products return null', () async {
    await cache.replaceAllMappings([
      _mapping('product-z'),
      _mapping('product-a'),
    ]);

    expect((await cache.getAllMappings()).map((mapping) => mapping.productId), [
      'product-a',
      'product-z',
    ]);
    expect(
      (await cache.getMappingForProduct('product-z'))?.productId,
      'product-z',
    );
    expect(await cache.getMappingForProduct('missing'), isNull);
  });

  test('rejects duplicate product IDs before replacing the cache', () async {
    await cache.replaceAllMappings([_mapping('product-good')]);

    await expectLater(
      cache.replaceAllMappings([_mapping('duplicate'), _mapping('duplicate')]),
      throwsFormatException,
    );

    expect((await cache.getAllMappings()).single.productId, 'product-good');
  });

  test('persists and restores every mapping field', () async {
    final strength = QuickQuoteProductMapping(
      productId: 'product-strength',
      status: QuickQuoteMappingStatus.eligible,
      section: QuickQuoteSection.strength,
      roleKey: 'leg_press',
      strengthArea: QuickQuoteStrengthArea.legs,
      loadType: QuickQuoteLoadType.plateLoaded,
      movementKey: 'squat',
      familyKey: 'torque',
      plateWeightKg: null,
      stationCount: null,
      selectionPriority: 11,
      upgradePriority: 22,
      updatedAt: DateTime.parse('2026-10-01T12:30:00Z'),
    );
    final plate = QuickQuoteProductMapping(
      productId: 'product-plate',
      status: QuickQuoteMappingStatus.eligible,
      section: QuickQuoteSection.weightPlate,
      roleKey: 'weight_plate',
      strengthArea: null,
      loadType: null,
      movementKey: null,
      familyKey: 'olympic',
      plateWeightKg: 20,
      stationCount: null,
      selectionPriority: 12,
      upgradePriority: 23,
      updatedAt: DateTime.parse('2026-10-01T12:31:00Z'),
    );
    final multiStation = QuickQuoteProductMapping(
      productId: 'product-multi',
      status: QuickQuoteMappingStatus.eligible,
      section: QuickQuoteSection.multifunction,
      roleKey: 'multi_station',
      strengthArea: null,
      loadType: null,
      movementKey: null,
      familyKey: null,
      plateWeightKg: null,
      stationCount: 4,
      selectionPriority: 13,
      upgradePriority: 24,
      updatedAt: DateTime.parse('2026-10-01T12:32:00Z'),
    );

    final originals = [strength, plate, multiStation];
    await cache.replaceAllMappings(originals);
    final restored = await cache.getAllMappings();

    expect(
      restored.map((mapping) => mapping.toCacheJson()),
      originals.map((mapping) => mapping.toCacheJson()).toList()..sort(
        (left, right) => (left['productId']! as String).compareTo(
          right['productId']! as String,
        ),
      ),
    );
  });
}

QuickQuoteProductMapping _mapping(String productId) => QuickQuoteProductMapping(
  productId: productId,
  status: QuickQuoteMappingStatus.eligible,
  section: QuickQuoteSection.cardio,
  roleKey: 'treadmill',
  strengthArea: null,
  loadType: null,
  movementKey: null,
  familyKey: null,
  plateWeightKg: null,
  stationCount: null,
  selectionPriority: 1,
  upgradePriority: 2,
  updatedAt: DateTime.utc(2026, 10),
);
