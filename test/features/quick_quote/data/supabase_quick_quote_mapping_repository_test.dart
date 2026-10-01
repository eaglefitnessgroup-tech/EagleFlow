import 'dart:async';
import 'dart:collection';

import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import 'package:eagleflow/features/quick_quote/data/sembast_quick_quote_mapping_cache.dart';
import 'package:eagleflow/features/quick_quote/data/supabase_quick_quote_mapping_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_mapping_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class FakeSupabaseQuickQuoteMappingRepository
    extends SupabaseQuickQuoteMappingRepository {
  FakeSupabaseQuickQuoteMappingRepository({
    required super.localCache,
    required super.supabase,
    super.sessionKeyProvider,
  });

  bool connected = true;
  Object? remoteError;
  List<dynamic> remoteRows = <dynamic>[];
  final Queue<Future<List<dynamic>>> queuedResponses =
      Queue<Future<List<dynamic>>>();

  @override
  bool get isConnectedToServer => connected;

  @override
  Future<List<dynamic>> fetchMappingsFromServer() async {
    if (queuedResponses.isNotEmpty) {
      return queuedResponses.removeFirst();
    }
    if (remoteError != null) throw remoteError!;
    return remoteRows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late SembastQuickQuoteMappingCache cache;
  late FakeSupabaseQuickQuoteMappingRepository repository;
  late String sessionKey;

  setUp(() async {
    database = await databaseFactoryMemory.openDatabase(
      'quick_quote_repository_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);
    cache = SembastQuickQuoteMappingCache();
    sessionKey = 'session-a';
    repository = FakeSupabaseQuickQuoteMappingRepository(
      localCache: cache,
      supabase: SupabaseService.resetForTestingAndReturn(),
      sessionKeyProvider: () => sessionKey,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Supabase fetch returns and caches every valid mapping', () async {
    repository.remoteRows = [
      _eligibleRow('product-b'),
      _manualExcludedRow('product-a'),
    ];

    final mappings = await repository.getAllMappings();

    expect(mappings.map((mapping) => mapping.productId), [
      'product-a',
      'product-b',
    ]);
    expect(mappings.first.isEligible, isFalse);
    expect((await cache.getAllMappings()).length, 2);
  });

  test('successful refresh replaces cache so stale rows disappear', () async {
    await cache.replaceAllMappings([
      _mappingFromRow(_eligibleRow('product-stale')),
    ]);
    repository.remoteRows = [_eligibleRow('product-current')];

    await repository.refreshMappings();

    expect((await cache.getAllMappings()).map((mapping) => mapping.productId), [
      'product-current',
    ]);
  });

  test('remote failure falls back to the last valid cache', () async {
    await cache.replaceAllMappings([
      _mappingFromRow(_eligibleRow('product-cached')),
    ]);
    repository.remoteError = StateError('network unavailable');

    final mappings = await repository.refreshMappings();

    expect(mappings.single.productId, 'product-cached');
  });

  test('offline with no cache reports a clear unavailable state', () async {
    repository.connected = false;

    await expectLater(
      repository.getAllMappings(),
      throwsA(isA<QuickQuoteMappingsUnavailableException>()),
    );
  });

  test('malformed remote data preserves and returns the good cache', () async {
    await cache.replaceAllMappings([
      _mappingFromRow(_eligibleRow('product-cached')),
    ]);
    repository.remoteRows = [
      _eligibleRow('product-bad')..['load_type'] = 'unknown',
    ];

    final mappings = await repository.refreshMappings();

    expect(mappings.single.productId, 'product-cached');
    expect((await cache.getAllMappings()).single.productId, 'product-cached');
  });

  test('an empty remote result is invalid and preserves the cache', () async {
    await cache.replaceAllMappings([
      _mappingFromRow(_eligibleRow('product-cached')),
    ]);
    repository.remoteRows = <dynamic>[];

    final mappings = await repository.refreshMappings();

    expect(mappings.single.productId, 'product-cached');
  });

  test('product lookup is deterministic', () async {
    repository.remoteRows = [
      _eligibleRow('product-b'),
      _eligibleRow('product-a'),
    ];

    expect(
      (await repository.getMappingForProduct('product-b'))?.productId,
      'product-b',
    );
    expect(await repository.getMappingForProduct('missing'), isNull);
  });

  test('duplicate remote product IDs fail safely', () async {
    repository.remoteRows = [
      _eligibleRow('duplicate'),
      _eligibleRow('duplicate'),
    ];

    await expectLater(
      repository.refreshMappings(),
      throwsA(isA<QuickQuoteMappingsUnavailableException>()),
    );
    expect(await cache.getAllMappings(), isEmpty);
  });

  test('older in-flight refresh cannot overwrite newer mappings', () async {
    final first = Completer<List<dynamic>>();
    final second = Completer<List<dynamic>>();
    repository.queuedResponses
      ..add(first.future)
      ..add(second.future);

    final olderRefresh = repository.refreshMappings();
    final newerRefresh = repository.refreshMappings();

    second.complete([_eligibleRow('product-new')]);
    expect((await newerRefresh).single.productId, 'product-new');

    first.complete([_eligibleRow('product-old')]);
    expect((await olderRefresh).single.productId, 'product-new');
    expect((await cache.getAllMappings()).single.productId, 'product-new');
  });

  test('a session change invalidates an in-flight refresh', () async {
    await cache.replaceAllMappings([
      _mappingFromRow(_eligibleRow('product-cached')),
    ]);
    final response = Completer<List<dynamic>>();
    repository.queuedResponses.add(response.future);

    final refresh = repository.refreshMappings();
    sessionKey = 'session-b';
    repository.invalidateSession();
    response.complete([_eligibleRow('product-stale-session')]);

    expect((await refresh).single.productId, 'product-cached');
    expect((await cache.getAllMappings()).single.productId, 'product-cached');
  });
}

Map<String, dynamic> _eligibleRow(String productId) => <String, dynamic>{
  'product_id': productId,
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

Map<String, dynamic> _manualExcludedRow(String productId) => <String, dynamic>{
  'product_id': productId,
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

QuickQuoteProductMapping _mappingFromRow(Map<String, dynamic> row) =>
    QuickQuoteProductMapping.fromSupabaseRow(row);
