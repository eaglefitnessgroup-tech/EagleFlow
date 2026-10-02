import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_configured_planner.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_generation_issue.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_request.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_result.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_test_fixture.dart';

void main() {
  const planner = QuickQuoteConfiguredPlanner();
  late List<Product> products;
  late List<QuickQuoteProductMapping> mappings;
  late QuickQuoteActiveConfiguration configuration;

  setUp(() {
    products = buildCompleteProducts();
    mappings = buildCompleteMappings();
    configuration = buildRuntimeConfiguration(products, mappings);
  });

  QuickQuoteResult plan({
    QuickQuoteActiveConfiguration? config,
    List<Product>? catalog,
    List<QuickQuoteProductMapping>? productMappings,
    String brand = 'Premier',
    double budget = 100000,
    String pin = 'APN',
    String plate = 'APL',
  }) => planner.plan(
    request: QuickQuoteRequest(
      targetBudget: budget,
      strengthBrand: brand,
      premierPinSeriesPrefix: isPremierBrand(brand) ? pin : null,
      premierPlateSeriesPrefix: isPremierBrand(brand) ? plate : null,
      vatBudgetMode: QuickQuoteVatBudgetMode.includingVat,
    ),
    configuration: config ?? configuration,
    products: catalog ?? products,
    mappings: productMappings ?? mappings,
  );

  test('Premier profile boundaries resolve from configuration', () {
    expect(plan(budget: 100000).selections, isNotEmpty);
    expect(plan(budget: 500000).selections, isNotEmpty);

    expect(
      () => plan(budget: 99999),
      throwsA(
        isA<QuickQuoteConfiguredPlanningException>().having(
          (error) => error.issue.type,
          'type',
          QuickQuoteGenerationIssueType.unsupportedBudget,
        ),
      ),
    );
    expect(
      () => plan(budget: 500001),
      throwsA(isA<QuickQuoteConfiguredPlanningException>()),
    );
  });

  test('Burnsport profile and boundary values are data-driven', () {
    final burnsportProducts = products
        .map(
          (product) => product.brand == 'Matrix'
              ? product.copyWith(brand: 'Burnsport')
              : product,
        )
        .toList();
    final burnsportConfig = _renameSecondaryBrand(
      configuration,
      brand: 'Burnsport',
      budgetMin: 350000,
      budgetMax: 449999,
      budgetRange: '350K–449K',
    );

    expect(
      plan(
        config: burnsportConfig,
        catalog: burnsportProducts,
        brand: 'Burnsport',
        budget: 350000,
      ).selections,
      isNotEmpty,
    );
    expect(
      plan(
        config: burnsportConfig,
        catalog: burnsportProducts,
        brand: 'Burnsport',
        budget: 449999,
      ).selections,
      isNotEmpty,
    );
    expect(
      () => plan(
        config: burnsportConfig,
        catalog: burnsportProducts,
        brand: 'Burnsport',
        budget: 349999,
      ),
      throwsA(isA<QuickQuoteConfiguredPlanningException>()),
    );
  });

  test('allocation products and quantities are authoritative', () {
    final result = plan();
    final profileAllocations = configuration.allocations
        .where((row) => row.profileId == 'PREMIER-TEST')
        .toList();

    expect(result.selections, hasLength(profileAllocations.length));
    for (var index = 0; index < profileAllocations.length; index++) {
      expect(
        result.selections[index].candidate.product.normalizedProductCode,
        profileAllocations[index].productCode,
      );
      expect(
        result.selections[index].quantity,
        profileAllocations[index].quantity,
      );
    }
    expect(
      result.subtotal,
      result.selections.fold<double>(
        0,
        (sum, selection) => sum + selection.lineSubtotal,
      ),
    );
    expect(result.vat, closeTo(result.subtotal * 0.05, 0.000001));
  });

  test('cardio product, quantity, and Review state come from allocation', () {
    final configured = _replaceAllocation(
      configuration,
      (row) => row.productId == 'cardio-treadmill',
      (row) => _copyAllocation(
        row,
        quantity: 6,
        reviewFlag: true,
        notes: 'Approved cardio fallback.',
      ),
    );

    final result = plan(config: configured);
    final treadmill = result.selections.singleWhere(
      (selection) => selection.configurationRoleKey == 'cardio_treadmill',
    );

    expect(treadmill.productId, 'cardio-treadmill');
    expect(treadmill.quantity, 6);
    expect(result.warnings.single.message, contains('cardio fallback'));
  });

  test('Smith, functional, station, and dumbbell rows are not invented', () {
    final result = plan();

    expect(
      result.selections
          .singleWhere(
            (row) =>
                row.configurationRoleKey == 'functional_multi_smith_machine',
          )
          .productId,
      'smith',
    );
    expect(
      result.selections
          .singleWhere(
            (row) =>
                row.configurationRoleKey ==
                'functional_multi_functional_trainer',
          )
          .productId,
      'functional',
    );
    final station = result.selections.singleWhere(
      (row) => row.kind == QuickQuoteSelectionKind.multiStation,
    );
    expect(station.productId, 'multi');
    expect(station.candidate.stationCount, 4);
    expect(
      result.selections
          .singleWhere(
            (row) => row.kind == QuickQuoteSelectionKind.dumbbellFullSet,
          )
          .quantity,
      1,
    );
    expect(result.dumbbellConfiguration.rackQuantity, 2);
  });

  test('live product price overrides stale configuration reference price', () {
    final changedCatalog = products
        .map(
          (product) => product.id == 'cardio-treadmill'
              ? product.copyWith(sellingPrice: 4321)
              : product,
        )
        .toList();

    final result = plan(catalog: changedCatalog);
    final treadmill = result.selections.singleWhere(
      (selection) => selection.productId == 'cardio-treadmill',
    );

    expect(treadmill.candidate.product.sellingPrice, 4321);
    expect(treadmill.candidate.product.sellingPrice, isNot(1099));
  });

  test('review fallback remains a visible non-blocking warning', () {
    final reviewed = _replaceAllocation(
      configuration,
      (row) => row.productId == 'cardio-treadmill',
      (row) =>
          _copyAllocation(row, reviewFlag: true, notes: 'Verify fallback.'),
    );

    final result = plan(config: reviewed);

    expect(result.warnings, hasLength(1));
    expect(
      result.warnings.single.type,
      QuickQuoteGenerationIssueType.reviewRequired,
    );
    expect(result.warnings.single.message, contains('Verify fallback'));
  });

  test(
    'Premier resolves the same configured movements into selected series',
    () {
      final expandedProducts = [...products];
      final expandedMappings = [...mappings];
      for (final mapping in mappings.where(
        (row) => row.section == QuickQuoteSection.strength,
      )) {
        final product = products.singleWhere(
          (row) => row.id == mapping.productId,
        );
        if (!isPremierBrand(product.brand)) continue;
        final selectedPrefix = mapping.loadType == QuickQuoteLoadType.pinLoaded
            ? 'PXN'
            : 'PXL';
        final selected = product.copyWith(
          id: 'selected-${product.id}',
          productCode: '$selectedPrefix-${mapping.strengthArea!.databaseValue}',
        );
        expandedProducts.add(selected);
        expandedMappings.add(_copyMapping(mapping, productId: selected.id));
      }

      final result = plan(
        catalog: expandedProducts,
        productMappings: expandedMappings,
        pin: 'PXN',
        plate: 'PXL',
      );
      final strength = result.selections.where(
        (selection) => selection.kind == QuickQuoteSelectionKind.strength,
      );

      expect(strength, isNotEmpty);
      expect(
        strength.every((selection) {
          final prefix = selection.loadType == QuickQuoteLoadType.pinLoaded
              ? 'PXN-'
              : 'PXL-';
          return selection.candidate.product.normalizedProductCode.startsWith(
            prefix,
          );
        }),
        isTrue,
      );
      expect(
        strength.map((selection) => selection.candidate.movementKey).toSet(),
        hasLength(strength.length),
      );
    },
  );

  test(
    'Premier keeps the configured SKU when it already matches the series',
    () {
      final referenceMapping = mappings.firstWhere(
        (row) => row.section == QuickQuoteSection.strength,
      );
      final referenceProduct = products.singleWhere(
        (row) => row.id == referenceMapping.productId,
      );
      final alternate = referenceProduct.copyWith(
        id: 'same-series-alternate',
        productCode:
            '${deriveTestSeriesPrefix(referenceProduct.productCode)}!ALT',
      );
      final adjustedMappings =
          mappings
              .map(
                (mapping) => mapping.productId == referenceMapping.productId
                    ? _copyMapping(
                        mapping,
                        productId: mapping.productId,
                        selectionPriority: 10,
                      )
                    : mapping,
              )
              .toList()
            ..add(
              _copyMapping(
                referenceMapping,
                productId: alternate.id,
                selectionPriority: 0,
              ),
            );

      final result = plan(
        catalog: [...products, alternate],
        productMappings: adjustedMappings,
      );

      expect(
        result.selections.where(
          (selection) => selection.productId == referenceProduct.id,
        ),
        hasLength(1),
      );
      expect(
        result.selections.any(
          (selection) => selection.productId == alternate.id,
        ),
        isFalse,
      );
    },
  );

  test('cross-series priority ties return a structured ambiguity', () {
    final expandedProducts = [...products];
    final expandedMappings = [...mappings];
    final premierMappings = mappings.where((mapping) {
      final product = products.singleWhere(
        (candidate) => candidate.id == mapping.productId,
      );
      return mapping.section == QuickQuoteSection.strength &&
          isPremierBrand(product.brand);
    }).toList();
    final ambiguousReference = premierMappings.first;

    for (final mapping in premierMappings) {
      final product = products.singleWhere(
        (candidate) => candidate.id == mapping.productId,
      );
      final prefix = mapping.loadType == QuickQuoteLoadType.pinLoaded
          ? 'PXN'
          : 'PXL';
      final variants = identical(mapping, ambiguousReference) ? 2 : 1;
      for (var index = 0; index < variants; index++) {
        final selected = product.copyWith(
          id: 'ambiguous-${mapping.productId}-$index',
          productCode: '$prefix-${mapping.strengthArea!.databaseValue}-$index',
        );
        expandedProducts.add(selected);
        expandedMappings.add(
          _copyMapping(mapping, productId: selected.id, selectionPriority: 1),
        );
      }
    }

    expect(
      () => plan(
        catalog: expandedProducts,
        productMappings: expandedMappings,
        pin: 'PXN',
        plate: 'PXL',
      ),
      throwsA(
        isA<QuickQuoteConfiguredPlanningException>().having(
          (error) => error.issue.type,
          'type',
          QuickQuoteGenerationIssueType.ambiguousConfiguredMovement,
        ),
      ),
    );
  });

  test('missing selected-series movement returns a structured issue', () {
    final expandedProducts = [...products];
    final expandedMappings = [...mappings];
    for (final mapping in mappings.where(
      (row) =>
          row.section == QuickQuoteSection.strength &&
          row.strengthArea != QuickQuoteStrengthArea.chest,
    )) {
      final product = products.singleWhere(
        (row) => row.id == mapping.productId,
      );
      if (!isPremierBrand(product.brand)) continue;
      final prefix = mapping.loadType == QuickQuoteLoadType.pinLoaded
          ? 'PXN'
          : 'PXL';
      final selected = product.copyWith(
        id: 'selected-${product.id}',
        productCode: '$prefix-${mapping.strengthArea!.databaseValue}',
      );
      expandedProducts.add(selected);
      expandedMappings.add(_copyMapping(mapping, productId: selected.id));
    }

    expect(
      () => plan(
        catalog: expandedProducts,
        productMappings: expandedMappings,
        pin: 'PXN',
        plate: 'PXL',
      ),
      throwsA(
        isA<QuickQuoteConfiguredPlanningException>().having(
          (error) => error.issue.type,
          'type',
          QuickQuoteGenerationIssueType.missingConfiguredMovement,
        ),
      ),
    );
  });

  test('configured plate family and quantity bypass old quantity tiers', () {
    final configured = _replaceAllocations(
      configuration,
      (row) => row.roleKey.contains('_weight_plate_')
          ? _copyAllocation(row, quantity: 14)
          : row,
    );

    final result = plan(config: configured);
    final plates = result.selections.where(
      (selection) => selection.kind == QuickQuoteSelectionKind.weightPlate,
    );

    expect(plates, hasLength(4));
    expect(plates.every((selection) => selection.quantity == 14), isTrue);
    expect(result.plateConfiguration.quantityEach, 14);
  });

  test('bench, complete barbell set, and rack rows are used directly', () {
    final extras = [
      testProduct(id: 'bench', name: 'Adjustable Bench', code: 'BENCH-1'),
      testProduct(id: 'barbell-set', name: 'Barbell Set', code: 'BAR-SET'),
      testProduct(id: 'barbell-rack', name: 'Barbell Rack', code: 'BAR-RACK'),
    ];
    final configured = _appendRows(configuration, extras);

    final result = plan(config: configured, catalog: [...products, ...extras]);

    expect(
      result.selections.singleWhere((row) => row.productId == 'bench').quantity,
      3,
    );
    expect(
      result.selections.where(
        (row) =>
            row.kind == QuickQuoteSelectionKind.barbellSet ||
            row.kind == QuickQuoteSelectionKind.barbellRack,
      ),
      hasLength(2),
    );
    expect(
      result.selections.any(
        (row) => row.configurationRoleKey?.contains('olympic_bar') == true,
      ),
      isFalse,
    );
  });

  test('inactive configured product fails instead of substituting by name', () {
    final catalog = products
        .map(
          (product) => product.id == 'dumbbell-full'
              ? product.copyWith(isActive: false)
              : product,
        )
        .toList();

    expect(
      () => plan(catalog: catalog),
      throwsA(
        isA<QuickQuoteConfiguredPlanningException>().having(
          (error) => error.issue.type,
          'type',
          QuickQuoteGenerationIssueType.inactiveConfiguredProduct,
        ),
      ),
    );
  });

  test(
    'over-target profile is returned intact and deterministically ordered',
    () {
      final expensive = products
          .map((product) => product.copyWith(sellingPrice: 10000))
          .toList();

      final first = plan(catalog: expensive);
      final second = plan(catalog: expensive);

      expect(first.status, QuickQuoteBudgetStatus.overTarget);
      expect(first.selections, hasLength(second.selections.length));
      expect(
        first.selections.map(_selectionSignature),
        second.selections.map(_selectionSignature),
      );
      expect(
        first.selections.map((selection) => selection.sectionOrder),
        orderedEquals(
          [...first.selections.map((selection) => selection.sectionOrder)]
            ..sort(),
        ),
      );
    },
  );
}

QuickQuoteActiveConfiguration _renameSecondaryBrand(
  QuickQuoteActiveConfiguration source, {
  required String brand,
  required double budgetMin,
  required double budgetMax,
  required String budgetRange,
}) => QuickQuoteActiveConfiguration(
  versionId: source.versionId,
  profiles: source.profiles.map((profile) {
    if (profile.profileId != 'MATRIX-TEST') return profile;
    return QuickQuoteBudgetProfile(
      profileId: profile.profileId,
      brand: brand,
      budgetRange: budgetRange,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
    );
  }).toList(),
  allocations: source.allocations,
  strengthPriorities: source.strengthPriorities.map((priority) {
    if (priority.brand != 'Matrix') return priority;
    return QuickQuoteConfigStrengthPriority(
      brand: brand,
      strengthArea: priority.strengthArea,
      priority: priority.priority,
      productCode: priority.productCode,
      productId: priority.productId,
      seriesPrefix: priority.seriesPrefix,
      loadType: priority.loadType,
      equipmentRole: priority.equipmentRole,
      automationRule: priority.automationRule,
      source: priority.source,
    );
  }).toList(),
  roleMappings: source.roleMappings,
  rules: source.rules,
);

QuickQuoteActiveConfiguration _replaceAllocation(
  QuickQuoteActiveConfiguration source,
  bool Function(QuickQuoteConfigAllocation) matches,
  QuickQuoteConfigAllocation Function(QuickQuoteConfigAllocation) replace,
) => _replaceAllocations(source, (row) => matches(row) ? replace(row) : row);

QuickQuoteActiveConfiguration _replaceAllocations(
  QuickQuoteActiveConfiguration source,
  QuickQuoteConfigAllocation Function(QuickQuoteConfigAllocation) replace,
) => QuickQuoteActiveConfiguration(
  versionId: source.versionId,
  profiles: source.profiles,
  allocations: source.allocations.map(replace).toList(),
  strengthPriorities: source.strengthPriorities,
  roleMappings: source.roleMappings,
  rules: source.rules,
);

QuickQuoteConfigAllocation _copyAllocation(
  QuickQuoteConfigAllocation source, {
  int? quantity,
  bool? reviewFlag,
  String? notes,
}) => QuickQuoteConfigAllocation(
  profileId: source.profileId,
  sectionOrder: source.sectionOrder,
  section: source.section,
  equipmentRole: source.equipmentRole,
  roleKey: source.roleKey,
  productCode: source.productCode,
  productId: source.productId,
  quantity: quantity ?? source.quantity,
  selectionMode: source.selectionMode,
  priority: source.priority,
  reviewFlag: reviewFlag ?? source.reviewFlag,
  notes: notes ?? source.notes,
);

QuickQuoteProductMapping _copyMapping(
  QuickQuoteProductMapping source, {
  required String productId,
  int? selectionPriority,
}) => QuickQuoteProductMapping(
  productId: productId,
  status: source.status,
  section: source.section,
  roleKey: source.roleKey,
  strengthArea: source.strengthArea,
  loadType: source.loadType,
  movementKey: source.movementKey,
  familyKey: source.familyKey,
  plateWeightKg: source.plateWeightKg,
  stationCount: source.stationCount,
  selectionPriority: selectionPriority ?? source.selectionPriority,
  upgradePriority: source.upgradePriority,
  updatedAt: source.updatedAt,
);

QuickQuoteActiveConfiguration _appendRows(
  QuickQuoteActiveConfiguration source,
  List<Product> products,
) {
  final allocations = [...source.allocations];
  final roleMappings = [...source.roleMappings];
  final rows = <(Product, String, String, int)>[
    (products[0], 'benches_adjustable_bench', 'Benches', 3),
    (products[1], 'free_weights_barbell_set', 'Free Weights', 1),
    (products[2], 'free_weights_barbell_rack', 'Free Weights', 1),
  ];
  for (final (product, roleKey, section, quantity) in rows) {
    allocations.add(
      QuickQuoteConfigAllocation(
        profileId: 'PREMIER-TEST',
        sectionOrder: 999,
        section: section,
        equipmentRole: product.name,
        roleKey: roleKey,
        productCode: product.normalizedProductCode,
        productId: product.id,
        quantity: quantity,
        selectionMode: 'Fixed role',
        priority: allocations.length + 1,
        reviewFlag: false,
        notes: '',
      ),
    );
    roleMappings.add(
      QuickQuoteConfigRoleMapping(
        productCode: product.normalizedProductCode,
        productId: product.id,
        productName: product.name,
        catalogBrand: product.brand,
        category: product.category,
        automationSection: section,
        automationRole: product.name,
        roleKey: roleKey,
        unitPriceAed: 1,
        autoEligible: 'Yes',
        notes: '',
      ),
    );
  }
  return QuickQuoteActiveConfiguration(
    versionId: source.versionId,
    profiles: source.profiles,
    allocations: allocations,
    strengthPriorities: source.strengthPriorities,
    roleMappings: roleMappings,
    rules: source.rules,
  );
}

String _selectionSignature(QuickQuoteSelection selection) =>
    '${selection.configurationRoleKey}|${selection.productId}|${selection.quantity}';
