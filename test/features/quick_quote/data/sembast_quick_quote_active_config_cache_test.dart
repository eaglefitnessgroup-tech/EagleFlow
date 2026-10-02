import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/quick_quote/data/sembast_quick_quote_active_config_cache.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../quick_quote_test_fixture.dart';

void main() {
  late SembastQuickQuoteActiveConfigCache cache;

  setUp(() async {
    final database = await databaseFactoryMemory.openDatabase(
      'quick_quote_active_config_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);
    cache = SembastQuickQuoteActiveConfigCache();
  });

  tearDown(() => DatabaseService().closeAndResetForTesting());

  test('round-trips one normalized active snapshot', () async {
    final configuration = buildRuntimeConfiguration(
      buildCompleteProducts(),
      buildCompleteMappings(),
    );

    await cache.replaceConfiguration(configuration);
    final restored = await cache.getConfiguration();

    expect(restored?.versionId, configuration.versionId);
    expect(restored?.profiles.length, configuration.profiles.length);
    expect(restored?.allocations.length, configuration.allocations.length);
    expect(
      restored?.strengthPriorities.length,
      configuration.strengthPriorities.length,
    );
    expect(restored?.roleMappings.length, configuration.roleMappings.length);
    expect(restored?.rules.length, configuration.rules.length);
  });

  test(
    'failed session guard atomically preserves last-known-good data',
    () async {
      final configuration = buildRuntimeConfiguration(
        buildCompleteProducts(),
        buildCompleteMappings(),
      );
      await cache.replaceConfiguration(configuration);
      final next = buildRuntimeConfiguration(
        buildCompleteProducts(),
        buildCompleteMappings(),
      );
      final replacement = QuickQuoteActiveConfiguration(
        versionId: 'replacement-version',
        profiles: next.profiles,
        allocations: next.allocations,
        strengthPriorities: next.strengthPriorities,
        roleMappings: next.roleMappings,
        rules: next.rules,
      );

      await expectLater(
        cache.replaceConfiguration(replacement, canCommit: () => false),
        throwsA(isA<QuickQuoteActiveConfigStaleSessionException>()),
      );

      expect(
        (await cache.getConfiguration())?.versionId,
        configuration.versionId,
      );
    },
  );
}
