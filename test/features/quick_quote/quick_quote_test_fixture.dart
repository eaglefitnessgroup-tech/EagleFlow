import 'dart:async';

import 'package:eagleflow/features/products/application/product_master_controller.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_controller.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_mapping_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';

class QuickQuoteFixture {
  QuickQuoteFixture({
    List<Product>? products,
    List<QuickQuoteProductMapping>? mappings,
    Object? refreshError,
    Object? cachedError,
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
       ) {
    productController = ProductMasterController(productRepository);
    controller = QuickQuoteController(
      productController: productController,
      mappingRepository: mappingRepository,
    );
  }

  final List<Product> products;
  final List<QuickQuoteProductMapping> mappings;
  final FakeProductRepository productRepository;
  final FakeMappingRepository mappingRepository;
  late final ProductMasterController productController;
  late final QuickQuoteController controller;

  Future<void> initialize() => controller.initialize();
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
