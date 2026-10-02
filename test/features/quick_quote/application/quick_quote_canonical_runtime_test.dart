import 'dart:io';

import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_configured_planner.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_draft_factory.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_xlsx_value_reader.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_request.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const workbookPath =
      'test/fixtures/EagleFlow_Quick_Quote_Budget_Automation_Master.xlsx';
  const mappingSeedPath =
      'supabase/migrations/20261001020000_seed_quick_quote_product_mappings.sql';
  const planner = QuickQuoteConfiguredPlanner();
  late List<Product> products;
  late List<QuickQuoteProductMapping> mappings;
  late QuickQuoteActiveConfiguration configuration;

  setUpAll(() {
    final bytes = File(workbookPath).readAsBytesSync();
    final sheets = QuickQuoteXlsxValueReader().read(bytes);
    products = _productsFromSourceProducts(sheets);
    final imported = QuickQuoteConfigWorkbookService().parseAndValidate(
      bytes: bytes,
      sourceFilename: QuickQuoteConfigWorkbookService.exportFilename,
      products: products,
    );
    expect(imported.canApply, isTrue);
    configuration = QuickQuoteActiveConfiguration(
      versionId: 'canonical-runtime',
      profiles: imported.configuration.profiles,
      allocations: imported.configuration.allocations,
      strengthPriorities: imported.configuration.strengthPriorities,
      roleMappings: imported.configuration.roleMappings,
      rules: imported.configuration.rules,
    );
    mappings = _mappingsFromSeed(
      File(mappingSeedPath).readAsStringSync(),
      products,
    );
    configuration.validate();
  });

  const scenarios = [
    _CanonicalScenario(
      name: 'Premier 250K',
      brand: 'Premier',
      budget: 250000,
      profileId: 'PREM-250-299',
      allocationCount: 43,
      subtotal: 272330,
      vat: 13616.5,
      grandTotal: 285946.5,
      warningCount: 3,
    ),
    _CanonicalScenario(
      name: 'Premier 350K',
      brand: 'Premier',
      budget: 350000,
      profileId: 'PREM-300-399',
      allocationCount: 49,
      subtotal: 333730,
      vat: 16686.5,
      grandTotal: 350416.5,
      warningCount: 3,
    ),
    _CanonicalScenario(
      name: 'Premier 500K',
      brand: 'Premier',
      budget: 500000,
      profileId: 'PREM-400-500',
      allocationCount: 57,
      subtotal: 436870,
      vat: 21843.5,
      grandTotal: 458713.5,
      warningCount: 3,
    ),
    _CanonicalScenario(
      name: 'Burnsport 350K',
      brand: 'Burnsport',
      budget: 350000,
      profileId: 'BURN-350-449',
      allocationCount: 38,
      subtotal: 418395.6,
      vat: 20919.78,
      grandTotal: 439315.38,
      warningCount: 4,
    ),
    _CanonicalScenario(
      name: 'Burnsport 500K',
      brand: 'Burnsport',
      budget: 500000,
      profileId: 'BURN-450-549',
      allocationCount: 44,
      subtotal: 518860,
      vat: 25943,
      grandTotal: 544803,
      warningCount: 4,
    ),
    _CanonicalScenario(
      name: 'Burnsport 700K',
      brand: 'Burnsport',
      budget: 700000,
      profileId: 'BURN-550-700',
      allocationCount: 49,
      subtotal: 622728,
      vat: 31136.4,
      grandTotal: 653864.4,
      warningCount: 5,
    ),
  ];

  for (final scenario in scenarios) {
    test('${scenario.name} uses the canonical active configuration', () {
      final profile = configuration.resolveProfile(
        scenario.brand,
        scenario.budget,
      );
      expect(profile?.profileId, scenario.profileId);

      final result = planner.plan(
        request: QuickQuoteRequest(
          targetBudget: scenario.budget,
          strengthBrand: scenario.brand,
          premierPinSeriesPrefix: scenario.brand == 'Premier' ? 'APN' : null,
          premierPlateSeriesPrefix: scenario.brand == 'Premier' ? 'APL' : null,
          vatBudgetMode: QuickQuoteVatBudgetMode.includingVat,
        ),
        configuration: configuration,
        products: products,
        mappings: mappings,
      );
      final expectedAllocations = _orderedAllocations(
        configuration,
        scenario.profileId,
      );
      final productsById = {
        for (final product in products) product.id: product,
      };

      expect(expectedAllocations, hasLength(scenario.allocationCount));
      expect(result.selections, hasLength(expectedAllocations.length));
      for (var index = 0; index < expectedAllocations.length; index++) {
        final allocation = expectedAllocations[index];
        final selection = result.selections[index];
        final liveProduct = productsById[selection.productId]!;
        expect(
          selection.candidate.product.normalizedProductCode,
          allocation.productCode,
          reason: '${scenario.name}: ${allocation.roleKey}',
        );
        expect(selection.quantity, allocation.quantity);
        expect(
          selection.candidate.product.sellingPrice,
          liveProduct.sellingPrice,
        );
        if (allocation.section.trim().toLowerCase() == 'strength') {
          expect(selection.candidate.product.brand, scenario.brand);
        }
      }
      expect(result.subtotal, closeTo(scenario.subtotal, 0.000001));
      expect(result.vat, closeTo(scenario.vat, 0.000001));
      expect(result.grandTotal, closeTo(scenario.grandTotal, 0.000001));
      expect(result.warnings, hasLength(scenario.warningCount));
      expect(QuickQuoteDraftFactory.canCreateDraft(result), isTrue);
    });
  }
}

List<QuickQuoteConfigAllocation> _orderedAllocations(
  QuickQuoteActiveConfiguration configuration,
  String profileId,
) {
  final indexed =
      configuration.allocations.indexed
          .where((entry) => entry.$2.profileId == profileId)
          .toList()
        ..sort((left, right) {
          var result = left.$2.sectionOrder.compareTo(right.$2.sectionOrder);
          if (result != 0) return result;
          result = left.$2.priority.compareTo(right.$2.priority);
          if (result != 0) return result;
          result = left.$1.compareTo(right.$1);
          if (result != 0) return result;
          return left.$2.productCode.compareTo(right.$2.productCode);
        });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

List<Product> _productsFromSourceProducts(
  Map<String, List<List<String>>> sheets,
) {
  final rows = sheets[QuickQuoteConfigWorkbookService.sourceProductsSheet]!;
  final headerIndex = rows.indexWhere(
    (row) => row.isNotEmpty && row.first.trim() == 'Product Code',
  );
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
    products.add(
      Product(
        id: 'canonical-${products.length + 1}',
        productCode: code,
        name: value(row, 'Product Name'),
        category: value(row, 'Category'),
        brand: value(row, 'Brand'),
        sellingPrice: double.parse(
          value(row, 'Selling Price').replaceAll(',', ''),
        ),
        isVatApplicable: _yes(value(row, 'VAT Applicable')),
        isActive: _yes(value(row, 'Active Product')),
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

List<QuickQuoteProductMapping> _mappingsFromSeed(
  String sql,
  List<Product> products,
) {
  final productsByCode = {
    for (final product in products) product.normalizedProductCode: product,
  };
  final pattern = RegExp(
    r"^\s*\('([^']+)', '([^']+)', (NULL|'[^']*'), (NULL|'[^']*'), (NULL|'[^']*'), (NULL|'[^']*'), (NULL|'[^']*'), (NULL|'[^']*'), (NULL|'[^']*'), (NULL|\d+), (\d+), (\d+)\)[,;]\s*$",
    multiLine: true,
  );
  final timestamp = DateTime.utc(2026, 10, 2);
  final mappings = <QuickQuoteProductMapping>[];
  for (final match in pattern.allMatches(sql)) {
    final product = productsByCode[match.group(1)!.toUpperCase()];
    if (product == null) continue;
    final mapping = QuickQuoteProductMapping(
      productId: product.id,
      status: QuickQuoteMappingStatus.parse(match.group(2)),
      section: QuickQuoteSection.parseNullable(_sqlText(match.group(3)!)),
      roleKey: _sqlText(match.group(4)!),
      strengthArea: QuickQuoteStrengthArea.parseNullable(
        _sqlText(match.group(5)!),
      ),
      loadType: QuickQuoteLoadType.parseNullable(_sqlText(match.group(6)!)),
      movementKey: _sqlText(match.group(7)!),
      familyKey: _sqlText(match.group(8)!),
      plateWeightKg: double.tryParse(_sqlText(match.group(9)!) ?? ''),
      stationCount: int.tryParse(match.group(10)!),
      selectionPriority: int.parse(match.group(11)!),
      upgradePriority: int.parse(match.group(12)!),
      updatedAt: timestamp,
    );
    mapping.validate();
    mappings.add(mapping);
  }
  return mappings;
}

String? _sqlText(String value) =>
    value == 'NULL' ? null : value.substring(1, value.length - 1);

bool _yes(String value) =>
    const {'1', 'true', 'yes', 'y'}.contains(value.trim().toLowerCase());

class _CanonicalScenario {
  const _CanonicalScenario({
    required this.name,
    required this.brand,
    required this.budget,
    required this.profileId,
    required this.allocationCount,
    required this.subtotal,
    required this.vat,
    required this.grandTotal,
    required this.warningCount,
  });

  final String name;
  final String brand;
  final double budget;
  final String profileId;
  final int allocationCount;
  final double subtotal;
  final double vat;
  final double grandTotal;
  final int warningCount;
}
