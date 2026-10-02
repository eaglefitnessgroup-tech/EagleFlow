import 'package:eagleflow/features/quick_quote/application/quick_quote_automation_logic_controller.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_config_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_config_test_fixture.dart';

void main() {
  late _MemoryConfigRepository repository;
  late QuickQuoteAutomationLogicController controller;
  late bool admin;
  late List<int>? savedBytes;

  setUp(() {
    repository = _MemoryConfigRepository();
    admin = true;
    savedBytes = null;
    controller = QuickQuoteAutomationLogicController(
      repository: repository,
      productLoader: () async => buildConfigProducts(),
      isAdmin: () => admin,
      fileSaver: ({required bytes, required filename}) async {
        savedBytes = bytes;
      },
    );
  });

  test(
    'successful import creates and activates a new immutable version',
    () async {
      await controller.initialize();
      await controller.validateWorkbook(
        filename: 'valid.xlsx',
        bytes: encodeWorkbook(buildValidConfigWorkbook()),
      );

      expect(controller.canApply, isTrue);
      expect(await controller.apply(), isTrue);
      expect(repository.applyCalls, 1);
      expect(controller.activeConfiguration?.version?.versionNumber, 1);
      expect(
        controller.history.where((version) => version.isActive),
        hasLength(1),
      );
    },
  );

  test('failed validation creates no version', () async {
    await controller.initialize();
    final workbook = buildValidConfigWorkbook();
    setWorkbookCell(
      workbook,
      QuickQuoteConfigWorkbookService.profileSheet,
      'D6',
      TextCellValue('invalid'),
    );
    await controller.validateWorkbook(
      filename: 'invalid.xlsx',
      bytes: encodeWorkbook(workbook),
    );

    expect(controller.canApply, isFalse);
    expect(await controller.apply(), isFalse);
    expect(repository.applyCalls, 0);
    expect(controller.history, isEmpty);
  });

  test(
    'partial repository failure leaves current active version unchanged',
    () async {
      repository.seed(_configurationWithVersion(1, active: true));
      await controller.initialize();
      await controller.validateWorkbook(
        filename: 'valid.xlsx',
        bytes: encodeWorkbook(buildValidConfigWorkbook()),
      );
      repository.failApply = true;

      expect(await controller.apply(), isFalse);
      expect(controller.activeConfiguration?.version?.versionNumber, 1);
      expect(repository.active?.version?.versionNumber, 1);
      expect(
        repository.history.where((version) => version.isActive),
        hasLength(1),
      );
    },
  );

  test(
    'rollback activates an old version without deleting newer versions',
    () async {
      repository
        ..seed(_configurationWithVersion(1, active: false))
        ..seed(_configurationWithVersion(2, active: true));
      await controller.initialize();

      expect(await controller.activateVersion('version-1'), isTrue);
      expect(controller.activeConfiguration?.version?.versionNumber, 1);
      expect(controller.history, hasLength(2));
      expect(
        controller.history.where((version) => version.isActive),
        hasLength(1),
      );
      expect(
        controller.history
            .singleWhere((version) => version.id == 'version-2')
            .isActive,
        isFalse,
      );
    },
  );

  test('download exports the active configuration as XLSX', () async {
    repository.seed(_configurationWithVersion(1, active: true));
    await controller.initialize();

    expect(await controller.downloadCurrentLogic(), isTrue);
    expect(savedBytes, isNotEmpty);
    expect(
      Excel.decodeBytes(savedBytes!).tables.keys,
      containsAll([
        QuickQuoteConfigWorkbookService.profileSheet,
        QuickQuoteConfigWorkbookService.allocationSheet,
        QuickQuoteConfigWorkbookService.strengthSheet,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        QuickQuoteConfigWorkbookService.rulesSheet,
      ]),
    );
  });

  test('non-admin controller access fails closed', () async {
    admin = false;

    await expectLater(controller.initialize(), throwsStateError);
    await expectLater(
      controller.validateWorkbook(
        filename: 'valid.xlsx',
        bytes: encodeWorkbook(buildValidConfigWorkbook()),
      ),
      throwsStateError,
    );
    expect(repository.applyCalls, 0);
  });
}

class _MemoryConfigRepository implements QuickQuoteConfigRepository {
  final Map<String, QuickQuoteConfiguration> _configurations = {};
  QuickQuoteConfiguration? active;
  int applyCalls = 0;
  bool failApply = false;

  List<QuickQuoteConfigVersion> get history =>
      _configurations.values
          .map((configuration) => configuration.version!)
          .toList()
        ..sort(
          (left, right) => right.versionNumber.compareTo(left.versionNumber),
        );

  void seed(QuickQuoteConfiguration configuration) {
    _configurations[configuration.version!.id] = configuration;
    if (configuration.version!.isActive) active = configuration;
  }

  @override
  Future<QuickQuoteConfiguration?> getActiveConfiguration() async => active;

  @override
  Future<List<QuickQuoteConfigVersion>> getVersionHistory() async => history;

  @override
  Future<QuickQuoteConfiguration> applyConfiguration({
    required String sourceFilename,
    required QuickQuoteConfiguration configuration,
    required QuickQuoteConfigValidationSummary validationSummary,
  }) async {
    applyCalls++;
    if (failApply) throw StateError('transaction rolled back');
    final nextNumber = _configurations.length + 1;
    _deactivateAll();
    final created = _withVersion(
      configuration,
      _version(nextNumber, active: true, filename: sourceFilename),
    );
    seed(created);
    return created;
  }

  @override
  Future<QuickQuoteConfiguration> activateVersion(String versionId) async {
    final selected = _configurations[versionId];
    if (selected == null) throw StateError('missing');
    _deactivateAll();
    final activated = _withVersion(
      selected,
      _version(
        selected.version!.versionNumber,
        active: true,
        filename: selected.version!.sourceFilename,
      ),
    );
    _configurations[versionId] = activated;
    active = activated;
    return activated;
  }

  void _deactivateAll() {
    for (final entry in _configurations.entries.toList()) {
      final configuration = entry.value;
      _configurations[entry.key] = _withVersion(
        configuration,
        _version(
          configuration.version!.versionNumber,
          active: false,
          filename: configuration.version!.sourceFilename,
        ),
      );
    }
  }
}

QuickQuoteConfiguration _configurationWithVersion(
  int number, {
  required bool active,
}) {
  final service = QuickQuoteConfigWorkbookService();
  final parsed = service.parseAndValidate(
    bytes: encodeWorkbook(buildValidConfigWorkbook()),
    sourceFilename: 'version-$number.xlsx',
    products: buildConfigProducts(),
  );
  return _withVersion(parsed.configuration, _version(number, active: active));
}

QuickQuoteConfiguration _withVersion(
  QuickQuoteConfiguration configuration,
  QuickQuoteConfigVersion version,
) => QuickQuoteConfiguration(
  profiles: configuration.profiles,
  allocations: configuration.allocations,
  strengthPriorities: configuration.strengthPriorities,
  roleMappings: configuration.roleMappings,
  rules: configuration.rules,
  version: version,
);

QuickQuoteConfigVersion _version(
  int number, {
  required bool active,
  String? filename,
}) => QuickQuoteConfigVersion(
  id: 'version-$number',
  versionNumber: number,
  sourceFilename: filename ?? 'version-$number.xlsx',
  createdAt: DateTime(2026, 10, 2, number),
  createdBy: 'ADMIN-001',
  isActive: active,
  activatedAt: active ? DateTime(2026, 10, 2, number) : null,
  activatedBy: active ? 'ADMIN-001' : null,
  validationSummary: const QuickQuoteConfigValidationSummary(
    profileCount: 1,
    allocationCount: 11,
    strengthPriorityCount: 1,
    roleMappingCount: 12,
    warningCount: 0,
    errorCount: 0,
  ),
);
