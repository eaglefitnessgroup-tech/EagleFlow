import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/quick_quote/data/quick_quote_active_config_cache.dart';
import 'package:eagleflow/features/quick_quote/data/supabase_quick_quote_active_config_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_test_fixture.dart';

void main() {
  late QuickQuoteActiveConfiguration configuration;
  late _MemoryCache cache;
  late String? sessionId;
  late _FakeRepository repository;

  setUp(() {
    configuration = buildRuntimeConfiguration(
      buildCompleteProducts(),
      buildCompleteMappings(),
    );
    cache = _MemoryCache();
    sessionId = 'user-1';
    repository = _FakeRepository(
      cache: cache,
      sessionIdProvider: () => sessionId,
    )..seed(configuration);
  });

  test('loads only the active normalized remote configuration', () async {
    final result = await repository.loadActiveConfiguration();

    expect(result.source, QuickQuoteActiveConfigSource.remote);
    expect(result.configuration.versionId, configuration.versionId);
    expect(repository.requestedTables, {
      'quick_quote_budget_profiles',
      'quick_quote_config_allocations',
      'quick_quote_config_strength_priorities',
      'quick_quote_config_role_mappings',
      'quick_quote_config_rules',
    });
    expect(cache.configuration?.versionId, configuration.versionId);
    expect(cache.replaceCalls, 1);
  });

  test(
    'uses the valid last-known-good cache when remote loading fails',
    () async {
      cache.configuration = configuration;
      repository.remoteError = StateError('offline');

      final result = await repository.loadActiveConfiguration();

      expect(result.source, QuickQuoteActiveConfigSource.cache);
      expect(result.configuration.versionId, configuration.versionId);
      expect(cache.replaceCalls, 0);
    },
  );

  test('malformed remote data never overwrites a valid cache', () async {
    cache.configuration = configuration;
    repository.rowsByTable['quick_quote_config_allocations'] = const [];

    final result = await repository.loadActiveConfiguration();

    expect(result.source, QuickQuoteActiveConfigSource.cache);
    expect(result.configuration.versionId, configuration.versionId);
    expect(cache.replaceCalls, 0);
  });

  test(
    'remote failure with no cache returns structured unavailable state',
    () async {
      repository.remoteError = StateError('offline');

      await expectLater(
        repository.loadActiveConfiguration(),
        throwsA(
          isA<QuickQuoteActiveConfigUnavailableException>().having(
            (error) => error.message,
            'message',
            contains('contact an administrator'),
          ),
        ),
      );
    },
  );

  test('stale user response cannot replace or return session state', () async {
    final gate = Completer<void>();
    repository.fetchGate = gate;
    final loading = repository.loadActiveConfiguration();

    sessionId = 'user-2';
    gate.complete();

    await expectLater(
      loading,
      throwsA(isA<QuickQuoteActiveConfigStaleSessionException>()),
    );
    expect(cache.configuration, isNull);
    expect(cache.replaceCalls, 0);
  });

  test('no active remote version does not resurrect an old cache', () async {
    cache.configuration = configuration;
    repository.activeVersionId = null;

    await expectLater(
      repository.loadActiveConfiguration(),
      throwsA(isA<QuickQuoteActiveConfigUnavailableException>()),
    );
    expect(cache.replaceCalls, 0);
  });
}

class _MemoryCache implements QuickQuoteActiveConfigCache {
  QuickQuoteActiveConfiguration? configuration;
  int replaceCalls = 0;

  @override
  Future<QuickQuoteActiveConfiguration?> getConfiguration() async =>
      configuration;

  @override
  Future<void> replaceConfiguration(
    QuickQuoteActiveConfiguration configuration, {
    bool Function()? canCommit,
  }) async {
    if (canCommit != null && !canCommit()) {
      throw const QuickQuoteActiveConfigStaleSessionException();
    }
    replaceCalls++;
    this.configuration = configuration;
  }
}

class _FakeRepository extends SupabaseQuickQuoteActiveConfigRepository {
  _FakeRepository({
    required _MemoryCache cache,
    required super.sessionIdProvider,
  }) : super(supabase: ServiceLocator().supabaseService, localCache: cache);

  String? activeVersionId = 'runtime-test-version';
  Object? remoteError;
  Completer<void>? fetchGate;
  final Map<String, List<dynamic>> rowsByTable = {};
  final Set<String> requestedTables = {};

  @override
  bool get hasClient => true;

  void seed(QuickQuoteActiveConfiguration configuration) {
    activeVersionId = configuration.versionId;
    rowsByTable['quick_quote_budget_profiles'] = configuration.profiles
        .map((row) => row.toPayload())
        .toList();
    rowsByTable['quick_quote_config_allocations'] = configuration.allocations
        .map((row) => row.toPayload())
        .toList();
    rowsByTable['quick_quote_config_strength_priorities'] = configuration
        .strengthPriorities
        .map((row) => row.toPayload())
        .toList();
    rowsByTable['quick_quote_config_role_mappings'] = configuration.roleMappings
        .map((row) => row.toPayload())
        .toList();
    rowsByTable['quick_quote_config_rules'] = configuration.rules
        .map((row) => row.toPayload())
        .toList();
  }

  @override
  Future<String?> fetchActiveVersionId() async {
    if (remoteError != null) throw remoteError!;
    await fetchGate?.future;
    return activeVersionId;
  }

  @override
  Future<List<dynamic>> fetchChildRows(String table, String versionId) async {
    requestedTables.add(table);
    return rowsByTable[table] ?? const [];
  }
}
