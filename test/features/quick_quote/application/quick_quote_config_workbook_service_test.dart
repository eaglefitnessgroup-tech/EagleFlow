import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_xlsx_value_reader.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_config_test_fixture.dart';

void main() {
  final service = QuickQuoteConfigWorkbookService();

  QuickQuoteConfigImportResult parse(Excel workbook) =>
      service.parseAndValidate(
        bytes: encodeWorkbook(workbook),
        sourceFilename: 'logic.xlsx',
        products: buildConfigProducts(),
      );

  bool hasError(QuickQuoteConfigImportResult result, String text) => result
      .errors
      .any((issue) => issue.message.toLowerCase().contains(text.toLowerCase()));

  group('canonical workbook structure and parsing', () {
    test('valid workbook parses and resolves product IDs', () {
      final result = parse(buildValidConfigWorkbook());

      expect(result.summary.errorCount, 0);
      expect(result.summary.profileCount, 1);
      expect(result.summary.allocationCount, 11);
      expect(result.summary.strengthPriorityCount, 1);
      expect(result.summary.roleMappingCount, 12);
      expect(result.configuration.allocations.first.productId, 'id-SMITH');
      expect(result.canApply, isTrue);
    });

    test('missing required sheet blocks Apply', () {
      final workbook = buildValidConfigWorkbook()
        ..delete(QuickQuoteConfigWorkbookService.rulesSheet);

      final result = parse(workbook);

      expect(hasError(result, 'required sheet is missing'), isTrue);
      expect(result.canApply, isFalse);
    });

    test('missing machine-readable column blocks Apply', () {
      final workbook = buildValidConfigWorkbook();
      setWorkbookCell(
        workbook,
        QuickQuoteConfigWorkbookService.profileSheet,
        'A5',
        TextCellValue('Wrong Header'),
      );

      expect(
        hasError(parse(workbook), 'required column "Profile ID" is missing'),
        isTrue,
      );
    });

    test('calculated and reference-only columns are not required', () {
      final workbook = buildValidConfigWorkbook();
      for (final address in ['F5', 'G5', 'H5', 'I5', 'J5', 'K5', 'L5']) {
        setWorkbookCell(
          workbook,
          QuickQuoteConfigWorkbookService.profileSheet,
          address,
          TextCellValue('Reference only'),
        );
      }
      for (final address in ['K2', 'L2', 'N2', 'O2', 'P2', 'Q2', 'R2']) {
        setWorkbookCell(
          workbook,
          QuickQuoteConfigWorkbookService.allocationSheet,
          address,
          TextCellValue('Reference only'),
        );
      }

      expect(parse(workbook).summary.errorCount, 0);
    });

    test('malformed required numeric value blocks Apply', () {
      final workbook = buildValidConfigWorkbook();
      setWorkbookCell(
        workbook,
        QuickQuoteConfigWorkbookService.profileSheet,
        'D6',
        TextCellValue('not-a-number'),
      );

      expect(
        hasError(parse(workbook), 'Budget Min must be a valid number'),
        isTrue,
      );
    });

    test('CSV filename is rejected before parsing', () {
      expect(
        () => service.parseAndValidate(
          bytes: const [1, 2, 3],
          sourceFilename: 'logic.csv',
          products: buildConfigProducts(),
        ),
        throwsFormatException,
      );
    });
  });

  group('product validation', () {
    test('unknown or deleted product code is rejected', () {
      final workbook = buildValidConfigWorkbook();
      setWorkbookCell(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'J3',
        TextCellValue('UNKNOWN'),
      );

      expect(
        hasError(parse(workbook), 'unknown or refers to a deleted'),
        isTrue,
      );
    });

    test('inactive product is rejected', () {
      final workbook = buildValidConfigWorkbook();
      setWorkbookCell(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'J3',
        TextCellValue('INACTIVE'),
      );

      expect(hasError(parse(workbook), 'is inactive'), isTrue);
    });

    test('duplicate normalized product code is rejected', () {
      final products = buildConfigProducts()
        ..add(buildConfigProducts().first.copyWith(id: 'duplicate-id'));
      final result = service.parseAndValidate(
        bytes: encodeWorkbook(buildValidConfigWorkbook()),
        sourceFilename: 'logic.xlsx',
        products: products,
      );

      expect(hasError(result, 'does not resolve uniquely'), isTrue);
    });
  });

  group('business validation', () {
    test('Smith Machine must be exactly one', () {
      final workbook = buildValidConfigWorkbook();
      _set(workbook, QuickQuoteConfigWorkbookService.allocationSheet, 'M3', 2);
      expect(
        hasError(parse(workbook), 'Smith Machine must be exactly Qty 1'),
        isTrue,
      );
    });

    test('Functional Trainer must be exactly one', () {
      final workbook = buildValidConfigWorkbook();
      _set(workbook, QuickQuoteConfigWorkbookService.allocationSheet, 'M4', 2);
      expect(
        hasError(parse(workbook), 'Functional Trainer must be exactly Qty 1'),
        isTrue,
      );
    });

    test('only one Multi Station model is permitted', () {
      final workbook = buildValidConfigWorkbook();
      workbook[QuickQuoteConfigWorkbookService.allocationSheet].appendRow(
        _allocationRow(
          role: '8 Station',
          roleKey: 'functional_multi_8_station',
          code: 'MS8',
        ),
      );
      expect(hasError(parse(workbook), 'Only one Multi Station'), isTrue);
    });

    test('12 Station and 16 Station values are rejected', () {
      final workbook = buildValidConfigWorkbook();
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'I5',
        'functional_multi_12_station',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'G6',
        'functional_multi_12_station',
      );
      expect(
        hasError(parse(workbook), 'must be an approved 4, 5, or 8'),
        isTrue,
      );
    });

    test('full dumbbell set requires two matching racks', () {
      final workbook = buildValidConfigWorkbook();
      _set(workbook, QuickQuoteConfigWorkbookService.allocationSheet, 'M7', 1);
      expect(
        hasError(parse(workbook), 'requires exactly 2 matching rack'),
        isTrue,
      );
    });

    test('half dumbbell set requires one matching rack', () {
      final workbook = buildValidConfigWorkbook();
      const key = 'free_weights_dumbbell_half_set_2_5_25kg';
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'I6',
        key,
      );
      _set(workbook, QuickQuoteConfigWorkbookService.roleMapSheet, 'G7', key);
      _set(workbook, QuickQuoteConfigWorkbookService.allocationSheet, 'M7', 1);
      expect(
        hasError(parse(workbook), 'Dumbbell configuration requires'),
        isFalse,
      );
    });

    test('dumbbell and rack families cannot be mixed', () {
      final workbook = buildValidConfigWorkbook();
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'J7',
        'HM-2017',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'A8',
        'HM-2017',
      );
      expect(
        hasError(parse(workbook), 'one matching Premier or Burnsport'),
        isTrue,
      );
    });

    test('weight plate family must contain all four required sizes', () {
      final workbook = buildValidConfigWorkbook();
      const duplicateKey = 'free_weights_tpu_weight_plate_10kg';
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'I8',
        duplicateKey,
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'G9',
        duplicateKey,
      );
      expect(hasError(parse(workbook), 'complete 2.5, 5, 10, and 20'), isTrue);
    });

    test('weight plate families and brands cannot be mixed', () {
      final workbook = buildValidConfigWorkbook();
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'I11',
        'free_weights_pu_weight_plate_20kg',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'J11',
        'BPLATE20',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'A12',
        'BPLATE20',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'G12',
        'free_weights_pu_weight_plate_20kg',
      );
      expect(hasError(parse(workbook), 'one family and one brand'), isTrue);
    });

    test('weight plate quantities must be consistent across sizes', () {
      final workbook = buildValidConfigWorkbook();
      _set(workbook, QuickQuoteConfigWorkbookService.allocationSheet, 'M11', 3);
      expect(hasError(parse(workbook), 'consistent quantity'), isTrue);
    });

    test('AED 200K Premier profile requires the TPU plate family', () {
      final workbook = buildValidConfigWorkbook();
      for (final entry in {
        8: 'free_weights_pu_weight_plate_2_5kg',
        9: 'free_weights_pu_weight_plate_5kg',
        10: 'free_weights_pu_weight_plate_10kg',
        11: 'free_weights_pu_weight_plate_20kg',
      }.entries) {
        _set(
          workbook,
          QuickQuoteConfigWorkbookService.allocationSheet,
          'I${entry.key}',
          entry.value,
        );
        _set(
          workbook,
          QuickQuoteConfigWorkbookService.roleMapSheet,
          'G${entry.key + 1}',
          entry.value,
        );
      }
      expect(
        hasError(parse(workbook), 'must use the TPU plate family'),
        isTrue,
      );
    });

    test('Barbell Set and rack must match the profile brand', () {
      final workbook = buildValidConfigWorkbook();
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'J13',
        'HM-2023',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'A14',
        'HM-2023',
      );
      expect(hasError(parse(workbook), 'must match the profile brand'), isTrue);
    });

    test('intentional reviewed barbell fallback remains a warning', () {
      final workbook = buildValidConfigWorkbook();
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'J13',
        'HM-2023',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.allocationSheet,
        'U13',
        'Yes',
      );
      _set(
        workbook,
        QuickQuoteConfigWorkbookService.roleMapSheet,
        'A14',
        'HM-2023',
      );
      final result = parse(workbook);
      expect(hasError(result, 'must match the profile brand'), isFalse);
      expect(result.summary.warningCount, greaterThan(0));
    });

    test('duplicate conflicting automation keys are rejected', () {
      final workbook = buildValidConfigWorkbook();
      workbook[QuickQuoteConfigWorkbookService.allocationSheet].appendRow(
        _allocationRow(
          role: 'Functional Trainer',
          roleKey: 'functional_multi_functional_trainer',
          code: 'FT2',
        ),
      );
      expect(
        hasError(parse(workbook), 'Duplicate conflicting automation role'),
        isTrue,
      );
    });

    test('strength priority conflicts are rejected', () {
      final workbook = buildValidConfigWorkbook();
      workbook[QuickQuoteConfigWorkbookService.strengthSheet].appendRow(
        [
          'Premier',
          'Chest',
          1,
          'SMITH',
          'Product SMITH',
          'APN',
          'Pin Loaded',
          'Chest Press',
          1000,
          'Preserve area and movement.',
          'Canonical fixture',
        ].map(_cell).toList(),
      );
      expect(hasError(parse(workbook), 'strength priority context'), isTrue);
    });
  });

  group('diff and export', () {
    test('calculates changed profile rows', () {
      final current = parse(buildValidConfigWorkbook()).configuration;
      final changedWorkbook = buildValidConfigWorkbook();
      _set(
        changedWorkbook,
        QuickQuoteConfigWorkbookService.profileSheet,
        'C6',
        'Changed Range',
      );
      final next = parse(changedWorkbook).configuration;
      final diff = service.calculateDiff(current, next);

      expect(diff.profiles.changed, 1);
      expect(diff.profiles.added, 0);
      expect(diff.profiles.removed, 0);
    });

    test('export preserves canonical structure and re-imports', () {
      final original = parse(buildValidConfigWorkbook()).configuration;
      final exported = service.export(original);
      final sheets = QuickQuoteXlsxValueReader().read(exported);

      expect(
        sheets.keys,
        containsAll(<String>[
          QuickQuoteConfigWorkbookService.profileSheet,
          QuickQuoteConfigWorkbookService.allocationSheet,
          QuickQuoteConfigWorkbookService.strengthSheet,
          QuickQuoteConfigWorkbookService.rulesSheet,
          QuickQuoteConfigWorkbookService.roleMapSheet,
          QuickQuoteConfigWorkbookService.sourceProductsSheet,
          QuickQuoteConfigWorkbookService.verificationSheet,
        ]),
      );
      expect(
        sheets[QuickQuoteConfigWorkbookService.profileSheet]![4],
        QuickQuoteConfigWorkbookService.profileHeaders,
      );
      expect(
        sheets[QuickQuoteConfigWorkbookService.allocationSheet]![1],
        QuickQuoteConfigWorkbookService.allocationHeaders,
      );
      expect(
        sheets[QuickQuoteConfigWorkbookService.roleMapSheet]![2],
        QuickQuoteConfigWorkbookService.roleMapHeaders,
      );

      final roundTrip = service.parseAndValidate(
        bytes: exported,
        sourceFilename: QuickQuoteConfigWorkbookService.exportFilename,
        products: buildConfigProducts(),
        currentConfiguration: original,
      );
      expect(roundTrip.summary.errorCount, 0);
      expect(roundTrip.diff.profiles.changed, 0);
      expect(roundTrip.diff.allocations.changed, 0);
      expect(roundTrip.diff.roleMappings.changed, 0);
    });
  });
}

void _set(Excel workbook, String sheet, String address, Object value) {
  setWorkbookCell(workbook, sheet, address, _cell(value));
}

List<CellValue> _allocationRow({
  required String role,
  required String roleKey,
  required String code,
}) => <Object>[
  'P200',
  'Premier',
  '200K-299K',
  200000,
  299999,
  1,
  'Functional / Multi',
  role,
  roleKey,
  code,
  'Product $code',
  'Premier',
  1,
  1000,
  1000,
  0.05,
  50,
  1050,
  'Fixed role',
  1,
  'No',
  '',
].map(_cell).toList();

CellValue _cell(Object value) => switch (value) {
  int value => IntCellValue(value),
  double value => DoubleCellValue(value),
  _ => TextCellValue(value.toString()),
};
