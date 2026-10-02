import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:eagleflow/features/quick_quote/data/supabase_quick_quote_config_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_config_test_fixture.dart';

void main() {
  late _FakeRepository repository;
  late QuickQuoteConfiguration configuration;

  setUp(() {
    ServiceLocator.resetForTesting();
    repository = _FakeRepository();
    configuration = QuickQuoteConfigWorkbookService()
        .parseAndValidate(
          bytes: encodeWorkbook(buildValidConfigWorkbook()),
          sourceFilename: 'logic.xlsx',
          products: buildConfigProducts(),
        )
        .configuration;
    repository.seed(configuration);
  });

  tearDown(ServiceLocator.resetForTesting);

  test('loads the active normalized configuration', () async {
    final loaded = await repository.getActiveConfiguration();

    expect(loaded?.version?.versionNumber, 1);
    expect(loaded?.profiles, hasLength(1));
    expect(loaded?.allocations, hasLength(11));
    expect(loaded?.allocations.first.productId, 'id-SMITH');
  });

  test('Apply sends complete normalized payload to the atomic RPC', () async {
    final applied = await repository.applyConfiguration(
      sourceFilename: 'uploaded.xlsx',
      configuration: configuration,
      validationSummary: const QuickQuoteConfigValidationSummary(
        profileCount: 1,
        allocationCount: 11,
        strengthPriorityCount: 1,
        roleMappingCount: 12,
        warningCount: 0,
        errorCount: 0,
      ),
    );

    expect(repository.applyCalls, 1);
    expect(repository.lastFilename, 'uploaded.xlsx');
    expect(repository.lastPayload?['profiles'], hasLength(1));
    expect(repository.lastPayload?['allocations'], hasLength(11));
    expect(
      (repository.lastPayload?['allocations'] as List).first['product_id'],
      'id-SMITH',
    );
    expect(applied.version?.id, 'version-1');
  });

  test('rollback delegates activation to the atomic RPC', () async {
    final active = await repository.activateVersion('version-1');

    expect(repository.activatedVersionId, 'version-1');
    expect(active.version?.isActive, isTrue);
  });
}

class _FakeRepository extends SupabaseQuickQuoteConfigRepository {
  _FakeRepository() : super(ServiceLocator().supabaseService);

  Map<String, dynamic>? versionRow;
  final Map<String, List<dynamic>> rowsByTable = {};
  int applyCalls = 0;
  String? lastFilename;
  Map<String, dynamic>? lastPayload;
  String? activatedVersionId;

  @override
  bool get hasClient => true;

  void seed(QuickQuoteConfiguration configuration) {
    versionRow = {
      'id': 'version-1',
      'version_number': 1,
      'source_filename': 'logic.xlsx',
      'created_at': '2026-10-02T10:00:00Z',
      'created_by': 'ADMIN-001',
      'activated_at': '2026-10-02T10:00:00Z',
      'activated_by': 'ADMIN-001',
      'is_active': true,
      'validation_summary': {
        'profiles': 1,
        'allocations': 11,
        'strength_priorities': 1,
        'role_mappings': 12,
        'warnings': 0,
        'errors': 0,
      },
    };
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
  Future<Map<String, dynamic>?> fetchActiveVersion() async => versionRow;

  @override
  Future<List<dynamic>> fetchVersionHistory() async => [versionRow!];

  @override
  Future<Map<String, dynamic>?> fetchVersionById(String versionId) async =>
      versionRow;

  @override
  Future<List<dynamic>> fetchChildRows(String table, String versionId) async =>
      rowsByTable[table] ?? const [];

  @override
  Future<dynamic> callApplyConfiguration({
    required String sourceFilename,
    required Map<String, dynamic> validationSummary,
    required Map<String, dynamic> payload,
  }) async {
    applyCalls++;
    lastFilename = sourceFilename;
    lastPayload = payload;
    return 'version-1';
  }

  @override
  Future<dynamic> callActivateVersion(String versionId) async {
    activatedVersionId = versionId;
    return versionId;
  }
}
