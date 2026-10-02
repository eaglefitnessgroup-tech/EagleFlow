import 'dart:async';

import 'package:eagleflow/features/products/application/product_master_controller.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_controller.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_active_config_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_mapping_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';

class QuickQuoteFixture {
  QuickQuoteFixture({
    List<Product>? products,
    List<QuickQuoteProductMapping>? mappings,
    Object? refreshError,
    Object? cachedError,
    QuickQuoteActiveConfiguration? activeConfiguration,
    Object? activeConfigurationError,
    QuickQuoteActiveConfigSource activeConfigurationSource =
        QuickQuoteActiveConfigSource.remote,
    Completer<List<Product>>? productCompleter,
  }) : products = products ?? buildCompleteProducts(),
       mappings = mappings ?? buildCompleteMappings(),
       productRepository = FakeProductRepository(
         products ?? buildCompleteProducts(),
         completer: productCompleter,
       ),
       mappingRepository = FakeMappingRepository(
         refreshed: mappings ?? buildCompleteMappings(),
         cached: mappings ?? buildCompleteMappings(),
         refreshError: refreshError,
         cachedError: cachedError,
       ),
       activeConfigRepository = FakeActiveConfigRepository(
         configuration:
             activeConfiguration ??
             buildRuntimeConfiguration(
               buildCompleteProducts(),
               buildCompleteMappings(),
             ),
         error: activeConfigurationError,
         source: activeConfigurationSource,
       ) {
    productController = ProductMasterController(productRepository);
    controller = QuickQuoteController(
      productController: productController,
      mappingRepository: mappingRepository,
      activeConfigRepository: activeConfigRepository,
    );
  }

  final List<Product> products;
  final List<QuickQuoteProductMapping> mappings;
  final FakeProductRepository productRepository;
  final FakeMappingRepository mappingRepository;
  final FakeActiveConfigRepository activeConfigRepository;
  late final ProductMasterController productController;
  late final QuickQuoteController controller;

  Future<void> initialize() => controller.initialize();
}

class FakeActiveConfigRepository implements QuickQuoteActiveConfigRepository {
  FakeActiveConfigRepository({
    required this.configuration,
    this.error,
    this.source = QuickQuoteActiveConfigSource.remote,
  });

  final QuickQuoteActiveConfiguration configuration;
  final Object? error;
  final QuickQuoteActiveConfigSource source;
  int loadCalls = 0;

  @override
  Future<QuickQuoteActiveConfigLoadResult> loadActiveConfiguration() async {
    loadCalls++;
    if (error != null) throw error!;
    return QuickQuoteActiveConfigLoadResult(
      configuration: configuration,
      source: source,
    );
  }
}

class FakeProductRepository implements ProductRepository {
  FakeProductRepository(this.products, {this.completer});

  final List<Product> products;
  final Completer<List<Product>>? completer;
  int getAllCalls = 0;

  @override
  Future<List<Product>> getAllProducts() {
    getAllCalls++;
    return completer?.future ?? Future.value(List.of(products));
  }

  @override
  Future<void> init() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMappingRepository implements QuickQuoteMappingRepository {
  FakeMappingRepository({
    required this.refreshed,
    required this.cached,
    this.refreshError,
    this.cachedError,
  });

  final List<QuickQuoteProductMapping> refreshed;
  final List<QuickQuoteProductMapping> cached;
  final Object? refreshError;
  final Object? cachedError;
  int refreshCalls = 0;
  int cachedCalls = 0;

  @override
  Future<List<QuickQuoteProductMapping>> refreshMappings() async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return List.of(refreshed);
  }

  @override
  Future<List<QuickQuoteProductMapping>> getAllMappings() async {
    cachedCalls++;
    if (cachedError != null) throw cachedError!;
    return List.of(cached);
  }

  @override
  Future<QuickQuoteProductMapping?> getMappingForProduct(
    String productId,
  ) async {
    for (final mapping in cached) {
      if (mapping.productId == productId) return mapping;
    }
    return null;
  }
}

List<Product> buildCompleteProducts() {
  final products = <Product>[];
  for (final role in QuickQuoteCardioRole.values) {
    products.add(
      testProduct(
        id: 'cardio-${role.mappingValue}',
        name: cardioTestLabel(role),
        code: 'C-${role.index}',
        brand: 'Cardio Pro',
        category: 'Commercial Cardio',
        price: 100,
      ),
    );
  }
  products
    ..add(
      testProduct(
        id: 'cardio-treadmill-alt',
        name: 'Treadmill Alternate',
        code: 'C-ALT',
        brand: 'Cardio Pro',
        category: 'Commercial Cardio',
        price: 80,
      ),
    )
    ..add(
      testProduct(
        id: 'cardio-rower',
        name: 'Rower Pro',
        code: 'ROW-1',
        brand: 'Cardio Pro',
        category: 'Commercial Cardio',
        price: 50,
      ),
    )
    ..add(
      testProduct(
        id: 'cardio-home',
        name: 'Home Treadmill',
        code: 'HOME-1',
        brand: 'Cardio Pro',
        category: 'Home Use Cardio',
        price: 40,
      ),
    );

  for (final area in QuickQuoteStrengthArea.values) {
    products
      ..add(
        testProduct(
          id: 'premier-${area.databaseValue}-pin',
          name: 'Premier ${strengthTestLabel(area)} Pin',
          code: 'APN-${area.index}',
          brand: 'Premier',
          category: 'Strength',
          price: 100,
        ),
      )
      ..add(
        testProduct(
          id: 'premier-${area.databaseValue}-plate',
          name: 'Premier ${strengthTestLabel(area)} Plate',
          code: 'APL-${area.index}',
          brand: 'Premier',
          category: 'Strength',
          price: 110,
        ),
      )
      ..add(
        testProduct(
          id: 'matrix-${area.databaseValue}-pin',
          name: 'Matrix ${strengthTestLabel(area)} Pin',
          code: 'MXN-${area.index}',
          brand: 'Matrix',
          category: 'Strength',
          price: 120,
        ),
      );
  }

  products
    ..add(
      testProduct(id: 'smith', name: 'Smith Machine', code: 'SM-1', price: 100),
    )
    ..add(
      testProduct(
        id: 'functional',
        name: 'Functional Trainer',
        code: 'FT-1',
        price: 100,
      ),
    )
    ..add(
      testProduct(id: 'multi', name: 'Multi Station', code: 'MS-1', price: 100),
    )
    ..add(
      testProduct(
        id: 'dumbbell-full',
        name: 'Dumbbell Full Set',
        code: 'DB-F',
        price: 100,
      ),
    )
    ..add(
      testProduct(
        id: 'dumbbell-rack',
        name: 'Dumbbell Rack',
        code: 'DB-R',
        price: 50,
      ),
    );
  for (final weight in quickQuoteRequiredPlateWeightsKg) {
    products.add(
      testProduct(
        id: 'plate-$weight',
        name: '$weight kg Weight Plate',
        code: 'PL-$weight',
        price: 10,
      ),
    );
  }
  return products;
}

List<QuickQuoteProductMapping> buildCompleteMappings() {
  final mappings = <QuickQuoteProductMapping>[];
  for (final role in QuickQuoteCardioRole.values) {
    mappings.add(
      testMapping(
        productId: 'cardio-${role.mappingValue}',
        section: QuickQuoteSection.cardio,
        roleKey: role.mappingValue,
        selectionPriority: 1,
      ),
    );
  }
  mappings
    ..add(
      testMapping(
        productId: 'cardio-treadmill-alt',
        section: QuickQuoteSection.cardio,
        roleKey: QuickQuoteCardioRole.treadmill.mappingValue,
        selectionPriority: 2,
      ),
    )
    ..add(
      testMapping(
        productId: 'cardio-rower',
        section: QuickQuoteSection.cardio,
        roleKey: 'rower',
      ),
    )
    ..add(
      testMapping(
        productId: 'cardio-home',
        section: QuickQuoteSection.cardio,
        roleKey: QuickQuoteCardioRole.treadmill.mappingValue,
        selectionPriority: 0,
      ),
    );

  for (final area in QuickQuoteStrengthArea.values) {
    mappings
      ..add(
        testMapping(
          productId: 'premier-${area.databaseValue}-pin',
          section: QuickQuoteSection.strength,
          roleKey: 'strength_machine',
          strengthArea: area,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: '${area.databaseValue}-pin',
        ),
      )
      ..add(
        testMapping(
          productId: 'premier-${area.databaseValue}-plate',
          section: QuickQuoteSection.strength,
          roleKey: 'strength_machine',
          strengthArea: area,
          loadType: QuickQuoteLoadType.plateLoaded,
          movementKey: '${area.databaseValue}-plate',
        ),
      )
      ..add(
        testMapping(
          productId: 'matrix-${area.databaseValue}-pin',
          section: QuickQuoteSection.strength,
          roleKey: 'strength_machine',
          strengthArea: area,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: '${area.databaseValue}-matrix',
        ),
      );
  }

  mappings
    ..add(
      testMapping(
        productId: 'smith',
        section: QuickQuoteSection.multifunction,
        roleKey: QuickQuoteMultifunctionRole.smithMachine.mappingValue,
      ),
    )
    ..add(
      testMapping(
        productId: 'functional',
        section: QuickQuoteSection.multifunction,
        roleKey: QuickQuoteMultifunctionRole.functionalTrainer.mappingValue,
      ),
    )
    ..add(
      testMapping(
        productId: 'multi',
        section: QuickQuoteSection.multifunction,
        roleKey: QuickQuoteMultifunctionRole.multiStation.mappingValue,
        stationCount: 4,
      ),
    )
    ..add(
      testMapping(
        productId: 'dumbbell-full',
        section: QuickQuoteSection.dumbbell,
        roleKey: quickQuoteDumbbellFullSetRole,
        familyKey: 'dumbbell-family',
      ),
    )
    ..add(
      testMapping(
        productId: 'dumbbell-rack',
        section: QuickQuoteSection.dumbbellRack,
        roleKey: quickQuoteDumbbellRackRole,
        familyKey: 'dumbbell-family',
      ),
    );
  for (final weight in quickQuoteRequiredPlateWeightsKg) {
    mappings.add(
      testMapping(
        productId: 'plate-$weight',
        section: QuickQuoteSection.weightPlate,
        roleKey: quickQuoteWeightPlateRole,
        familyKey: 'plate-family',
        plateWeightKg: weight,
      ),
    );
  }
  return mappings;
}

QuickQuoteActiveConfiguration buildRuntimeConfiguration(
  List<Product> products,
  List<QuickQuoteProductMapping> mappings, {
  double budgetMin = 100000,
  double budgetMax = 500000,
}) {
  final productsById = {for (final product in products) product.id: product};
  final allocations = <QuickQuoteConfigAllocation>[];
  final roleMappings = <QuickQuoteConfigRoleMapping>[];
  final strengthPriorities = <QuickQuoteConfigStrengthPriority>[];
  var sectionOrder = 0;

  void addAllocation({
    required String profileId,
    required Product product,
    required String section,
    required String role,
    required String roleKey,
    required int priority,
    int quantity = 1,
    bool review = false,
  }) {
    allocations.add(
      QuickQuoteConfigAllocation(
        profileId: profileId,
        sectionOrder: ++sectionOrder,
        section: section,
        equipmentRole: role,
        roleKey: roleKey,
        productCode: product.normalizedProductCode,
        productId: product.id,
        quantity: quantity,
        selectionMode: 'Fixed role',
        priority: priority,
        reviewFlag: review,
        notes: review ? 'Confirm approved fallback.' : '',
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
        automationRole: role,
        roleKey: roleKey,
        unitPriceAed: product.sellingPrice + 999,
        autoEligible: review ? 'Review' : 'Yes',
        notes: review ? 'Confirm approved fallback.' : '',
      ),
    );
  }

  void addSharedAllocations(String profileId) {
    for (final role in QuickQuoteCardioRole.values) {
      final product = productsById['cardio-${role.mappingValue}'];
      if (product != null) {
        addAllocation(
          profileId: profileId,
          product: product,
          section: 'Cardio',
          role: cardioTestLabel(role),
          roleKey: 'cardio_${role.mappingValue}',
          priority: role.index + 1,
        );
      }
    }
    final shared = <(String, String, String, String, int)>[
      (
        'smith',
        'Functional / Multi',
        'Smith Machine',
        'functional_multi_smith_machine',
        1,
      ),
      (
        'functional',
        'Functional / Multi',
        'Functional Trainer',
        'functional_multi_functional_trainer',
        2,
      ),
      (
        'multi',
        'Functional / Multi',
        '4 Station',
        'functional_multi_4_station',
        3,
      ),
      (
        'dumbbell-full',
        'Free Weights',
        'Dumbbell Full Set 2.5–50kg',
        'free_weights_dumbbell_full_set_2_5_50kg',
        1,
      ),
      (
        'dumbbell-rack',
        'Free Weights',
        'Dumbbell Rack',
        'free_weights_dumbbell_rack',
        2,
      ),
    ];
    for (final row in shared) {
      final product = productsById[row.$1];
      if (product == null) continue;
      addAllocation(
        profileId: profileId,
        product: product,
        section: row.$2,
        role: row.$3,
        roleKey: row.$4,
        priority: row.$5,
        quantity: row.$1 == 'dumbbell-rack' ? 2 : 1,
      );
    }
    for (final weight in quickQuoteRequiredPlateWeightsKg) {
      final product = productsById['plate-$weight'];
      if (product == null) continue;
      final token = weight == 2.5 ? '2_5' : weight.toInt().toString();
      addAllocation(
        profileId: profileId,
        product: product,
        section: 'Free Weights',
        role: '$weight kg Weight Plate',
        roleKey: 'free_weights_tpu_weight_plate_${token}kg',
        priority: weight.round(),
        quantity: 8,
      );
    }
  }

  void addStrength(String profileId, String brand) {
    final brandMappings = mappings.where(
      (mapping) =>
          mapping.section == QuickQuoteSection.strength &&
          productsById[mapping.productId]?.brand == brand,
    );
    var priority = 0;
    for (final mapping in brandMappings) {
      final product = productsById[mapping.productId]!;
      addAllocation(
        profileId: profileId,
        product: product,
        section: 'Strength',
        role: strengthTestLabel(mapping.strengthArea!),
        roleKey: 'strength_${mapping.strengthArea!.databaseValue}',
        priority: ++priority,
      );
      strengthPriorities.add(
        QuickQuoteConfigStrengthPriority(
          brand: brand,
          strengthArea: strengthTestLabel(mapping.strengthArea!),
          priority: priority,
          productCode: product.normalizedProductCode,
          productId: product.id,
          seriesPrefix: deriveTestSeriesPrefix(product.productCode),
          loadType: mapping.loadType == QuickQuoteLoadType.pinLoaded
              ? 'Pin Loaded'
              : 'Plate Loaded',
          equipmentRole: strengthTestLabel(mapping.strengthArea!),
          automationRule: 'Preserve movement.',
          source: 'Runtime fixture',
        ),
      );
    }
  }

  addSharedAllocations('PREMIER-TEST');
  addStrength('PREMIER-TEST', 'Premier');
  addSharedAllocations('MATRIX-TEST');
  addStrength('MATRIX-TEST', 'Matrix');

  final uniqueRoleMappings = <String, QuickQuoteConfigRoleMapping>{};
  for (final mapping in roleMappings) {
    uniqueRoleMappings['${mapping.productCode}|${mapping.roleKey}'] = mapping;
  }
  return QuickQuoteActiveConfiguration(
    versionId: 'runtime-test-version',
    profiles: [
      QuickQuoteBudgetProfile(
        profileId: 'PREMIER-TEST',
        brand: 'Premier',
        budgetRange: '100K–500K',
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      ),
      QuickQuoteBudgetProfile(
        profileId: 'MATRIX-TEST',
        brand: 'Matrix',
        budgetRange: '100K–500K',
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      ),
    ],
    allocations: allocations,
    strengthPriorities: strengthPriorities,
    roleMappings: uniqueRoleMappings.values.toList(),
    rules: const [
      QuickQuoteConfigRule(
        rule: 'Runtime test rule',
        premier: 'Configured',
        burnsport: 'Configured',
        automationNote: 'Use active profile allocations.',
      ),
    ],
  );
}

String deriveTestSeriesPrefix(String productCode) {
  final match = RegExp(r'^[A-Za-z]+').firstMatch(productCode.trim());
  return match?.group(0)?.toUpperCase() ?? '';
}

Product testProduct({
  required String id,
  required String name,
  required String code,
  String brand = 'Utility',
  String category = 'Gym Equipment',
  double price = 100,
  bool isActive = true,
  bool isVatApplicable = true,
}) => Product(
  id: id,
  productCode: code,
  name: name,
  category: category,
  brand: brand,
  sellingPrice: price,
  isActive: isActive,
  isVatApplicable: isVatApplicable,
  createdAt: DateTime.utc(2026, 10),
  updatedAt: DateTime.utc(2026, 10),
);

QuickQuoteProductMapping testMapping({
  required String productId,
  required QuickQuoteSection section,
  required String roleKey,
  QuickQuoteStrengthArea? strengthArea,
  QuickQuoteLoadType? loadType,
  String? movementKey,
  String? familyKey,
  double? plateWeightKg,
  int? stationCount,
  int selectionPriority = 0,
}) => QuickQuoteProductMapping(
  productId: productId,
  status: QuickQuoteMappingStatus.eligible,
  section: section,
  roleKey: roleKey,
  strengthArea: strengthArea,
  loadType: loadType,
  movementKey: movementKey,
  familyKey: familyKey,
  plateWeightKg: plateWeightKg,
  stationCount: stationCount,
  selectionPriority: selectionPriority,
  upgradePriority: selectionPriority,
  updatedAt: DateTime.utc(2026, 10),
);

String cardioTestLabel(QuickQuoteCardioRole role) => switch (role) {
  QuickQuoteCardioRole.treadmill => 'Commercial Treadmill',
  QuickQuoteCardioRole.crossTrainer => 'Commercial Cross Trainer',
  QuickQuoteCardioRole.recumbentBike => 'Commercial Recumbent Bike',
  QuickQuoteCardioRole.uprightBike => 'Commercial Upright Bike',
  QuickQuoteCardioRole.spinningBike => 'Commercial Spinning Bike',
};

String strengthTestLabel(QuickQuoteStrengthArea area) => switch (area) {
  QuickQuoteStrengthArea.chest => 'Chest',
  QuickQuoteStrengthArea.back => 'Back',
  QuickQuoteStrengthArea.shoulder => 'Shoulder',
  QuickQuoteStrengthArea.legs => 'Legs',
  QuickQuoteStrengthArea.arms => 'Arms',
  QuickQuoteStrengthArea.glutes => 'Glutes',
  QuickQuoteStrengthArea.core => 'Core',
};
