import 'dart:io';

import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_xlsx_value_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fixturePath =
      'test/fixtures/EagleFlow_Quick_Quote_Budget_Automation_Master.xlsx';
  final service = QuickQuoteConfigWorkbookService();
  final reader = QuickQuoteXlsxValueReader();

  test('exact canonical workbook imports, exports, and re-imports', () {
    final bytes = File(fixturePath).readAsBytesSync();
    final sheets = reader.read(bytes);
    final products = _productsFromSourceProducts(sheets);

    final imported = service.parseAndValidate(
      bytes: bytes,
      sourceFilename: QuickQuoteConfigWorkbookService.exportFilename,
      products: products,
    );

    expect(imported.summary.profileCount, 6);
    expect(imported.summary.allocationCount, 280);
    expect(imported.summary.strengthPriorityCount, 73);
    expect(imported.summary.roleMappingCount, 106);
    expect(imported.configuration.rules, hasLength(20));
    expect(imported.summary.errorCount, 0, reason: _issues(imported.errors));
    expect(imported.summary.warningCount, 22);
    expect(imported.canApply, isTrue);

    final exported = service.export(imported.configuration);
    final exportedSheets = reader.read(exported);
    _expectCanonicalHeaders(exportedSheets);

    final reimported = service.parseAndValidate(
      bytes: exported,
      sourceFilename: QuickQuoteConfigWorkbookService.exportFilename,
      products: products,
      currentConfiguration: imported.configuration,
    );
    expect(
      reimported.summary.errorCount,
      0,
      reason: _issues(reimported.errors),
    );
    expect(reimported.summary.warningCount, 22);
    expect(reimported.summary.profileCount, imported.summary.profileCount);
    expect(
      reimported.summary.allocationCount,
      imported.summary.allocationCount,
    );
    expect(
      reimported.summary.strengthPriorityCount,
      imported.summary.strengthPriorityCount,
    );
    expect(
      reimported.summary.roleMappingCount,
      imported.summary.roleMappingCount,
    );
    expect(reimported.diff.profiles.changed, 0);
    expect(reimported.diff.allocations.changed, 0);
    expect(reimported.diff.strengthPriorities.changed, 0);
    expect(reimported.diff.roleMappings.changed, 0);
  });
}

List<Product> _productsFromSourceProducts(
  Map<String, List<List<String>>> sheets,
) {
  final rows = sheets[QuickQuoteConfigWorkbookService.sourceProductsSheet]!;
  final headerIndex = rows.indexWhere(
    (row) => row.isNotEmpty && row.first.trim() == 'Product Code',
  );
  if (headerIndex < 0) {
    throw StateError('Canonical Source Products header was not found.');
  }
  final headers = rows[headerIndex];
  final columns = <String, int>{
    for (var index = 0; index < headers.length; index++)
      headers[index].trim(): index,
  };
  String value(List<String> row, String header) {
    final index = columns[header];
    return index == null || index >= row.length ? '' : row[index].trim();
  }

  final timestamp = DateTime.utc(2026, 10, 2);
  final products = <Product>[];
  for (final row in rows.skip(headerIndex + 1)) {
    final code = value(row, 'Product Code');
    if (code.isEmpty) continue;
    final price = double.parse(value(row, 'Selling Price').replaceAll(',', ''));
    final active = value(row, 'Active Product').toLowerCase();
    products.add(
      Product(
        id: 'canonical-${products.length + 1}',
        productCode: code,
        name: value(row, 'Product Name'),
        category: value(row, 'Category'),
        brand: value(row, 'Brand'),
        sellingPrice: price,
        isVatApplicable: _yes(value(row, 'VAT Applicable')),
        isActive: _yes(active),
        createdAt: timestamp,
        updatedAt: timestamp,
        description: value(row, 'Description / Notes'),
        unit: value(row, 'Unit'),
        minStockLevel: int.tryParse(value(row, 'Min Stock Level')) ?? 0,
      ),
    );
  }
  return products;
}

bool _yes(String value) =>
    const {'1', 'true', 'yes', 'y'}.contains(value.trim().toLowerCase());

void _expectCanonicalHeaders(Map<String, List<List<String>>> sheets) {
  expect(
    sheets[QuickQuoteConfigWorkbookService.profileSheet]![4],
    QuickQuoteConfigWorkbookService.profileHeaders,
  );
  expect(
    sheets[QuickQuoteConfigWorkbookService.allocationSheet]![1],
    QuickQuoteConfigWorkbookService.allocationHeaders,
  );
  expect(
    sheets[QuickQuoteConfigWorkbookService.strengthSheet]![2],
    QuickQuoteConfigWorkbookService.strengthHeaders,
  );
  expect(
    sheets[QuickQuoteConfigWorkbookService.rulesSheet]![2],
    QuickQuoteConfigWorkbookService.rulesHeaders,
  );
  expect(
    sheets[QuickQuoteConfigWorkbookService.roleMapSheet]![2],
    QuickQuoteConfigWorkbookService.roleMapHeaders,
  );
  expect(
    sheets[QuickQuoteConfigWorkbookService.sourceProductsSheet]![2],
    QuickQuoteConfigWorkbookService.sourceProductHeaders,
  );
  expect(
    sheets[QuickQuoteConfigWorkbookService.verificationSheet]![2],
    QuickQuoteConfigWorkbookService.verificationHeaders,
  );
}

String _issues(Iterable<dynamic> issues) =>
    issues.map((issue) => '${issue.location}: ${issue.message}').join('\n');
