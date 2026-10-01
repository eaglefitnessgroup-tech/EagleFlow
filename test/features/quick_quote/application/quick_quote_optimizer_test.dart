import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_candidate_preparer.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_optimizer.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_candidate_pool.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_request.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_result.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_selection.dart';
import 'package:eagleflow/features/quotations/application/quotation_calculator.dart';
import 'package:eagleflow/features/quotations/application/quotation_line_item_factory.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const optimizer = QuickQuoteOptimizer();

  group('determinism and validation', () {
    test('same input produces an identical result', () {
      final pool = _standardBuilder().build();
      final first = _optimize(optimizer, pool, 10000);
      final second = _optimize(optimizer, pool, 10000);

      expect(_signature(first), _signature(second));
      expect(first.subtotal, second.subtotal);
      expect(first.vat, second.vat);
      expect(first.grandTotal, second.grandTotal);
    });

    test('shuffled candidate input produces an identical result', () {
      final pool = _standardBuilder(
        includeCounterparts: true,
        includeMultifunction: true,
        includeHalfSet: true,
        includeUniqueExtra: true,
      ).build();
      final shuffled = _reversedPool(pool);

      final first = _optimize(optimizer, pool, 100000);
      final second = _optimize(optimizer, shuffled, 100000);

      expect(_signature(first), _signature(second));
      expect(first.grandTotal, second.grandTotal);
    });

    test('target budget at or below zero is rejected', () {
      expect(() => _request(0), throwsArgumentError);
      expect(() => _request(-1), throwsArgumentError);
    });
  });

  group('minimum balanced portfolio', () {
    test('includes all seven strength areas', () {
      final result = _minimumResult(optimizer, _standardBuilder().build());

      expect(result.strengthCoverage.keys, QuickQuoteStrengthArea.values);
      expect(
        result.strengthCoverage.values.every(
          (coverage) => coverage.hasCoverage,
        ),
        isTrue,
      );
    });

    test('does not require both Pin and Plate for minimum coverage', () {
      final pool = _standardBuilder(includeCounterparts: true).build();
      final result = _minimumResult(optimizer, pool);

      expect(
        result.strengthCoverage.values.every(
          (coverage) => coverage.pinCount + coverage.plateCount == 1,
        ),
        isTrue,
      );
    });

    test('includes all five available cardio roles', () {
      final result = _minimumResult(optimizer, _standardBuilder().build());

      expect(result.selectedCardioRoles, QuickQuoteCardioRole.values);
    });

    test('includes one full dumbbell set and exactly two racks', () {
      final result = _minimumResult(optimizer, _standardBuilder().build());

      expect(result.dumbbellConfiguration.hasFullSet, isTrue);
      expect(result.dumbbellConfiguration.hasHalfSet, isFalse);
      expect(result.dumbbellConfiguration.rackQuantity, 2);
    });

    test('uses the 8-each weight plate tier', () {
      final result = _minimumResult(optimizer, _standardBuilder().build());

      expect(result.plateConfiguration.quantityEach, 8);
      expect(
        result.selections
            .where(
              (selection) =>
                  selection.kind == QuickQuoteSelectionKind.weightPlate,
            )
            .map((selection) => selection.quantity)
            .toSet(),
        {8},
      );
    });

    test('Smith Machine is not mandatory minimum equipment', () {
      final pool = _standardBuilder(includeMultifunction: true).build();
      final result = _minimumResult(optimizer, pool);

      expect(
        result.selections.any(
          (selection) => selection.kind == QuickQuoteSelectionKind.smithMachine,
        ),
        isFalse,
      );
    });

    test('Functional Trainer is not mandatory minimum equipment', () {
      final pool = _standardBuilder(includeMultifunction: true).build();
      final result = _minimumResult(optimizer, pool);

      expect(
        result.selections.any(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.functionalTrainer,
        ),
        isFalse,
      );
    });

    test('Multi Station is not mandatory minimum equipment', () {
      final pool = _standardBuilder(includeMultifunction: true).build();
      final result = _minimumResult(optimizer, pool);

      expect(
        result.selections.any(
          (selection) => selection.kind == QuickQuoteSelectionKind.multiStation,
        ),
        isFalse,
      );
    });
  });

  group('insufficient budget', () {
    test('returns minimum total and shortfall', () {
      final pool = _standardBuilder().build();
      final result = _optimize(optimizer, pool, 1000);

      expect(result.status, QuickQuoteBudgetStatus.insufficientBudget);
      expect(result.grandTotal, result.minimumBalancedGrandTotal);
      expect(
        result.minimumBalancedShortfall,
        result.minimumBalancedGrandTotal - 1000,
      );
    });

    test('does not delete random sections from the minimum portfolio', () {
      final pool = _standardBuilder().build();
      final result = _optimize(optimizer, pool, 1);

      expect(result.selectedCardioRoles, QuickQuoteCardioRole.values);
      expect(
        result.strengthCoverage.values.every(
          (coverage) => coverage.hasCoverage,
        ),
        isTrue,
      );
      expect(result.dumbbellConfiguration.hasFullSet, isTrue);
      expect(result.plateConfiguration.quantityEach, 8);
    });
  });

  group('strength expansion', () {
    test('Pin/Plate counterparts are added before lower-priority extras', () {
      final builder = _standardBuilder()
        ..addStrength(
          id: 'chest-plate',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.plateLoaded,
          movementKey: 'chest_fly',
          price: 100,
          priority: 1,
        )
        ..addStrength(
          id: 'chest-extra',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: 'incline_press',
          price: 90,
          priority: 5,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 90);

      expect(
        result.selections.any(
          (selection) => selection.productId == 'chest-plate',
        ),
        isTrue,
      );
      expect(
        result.selections.any(
          (selection) => selection.productId == 'chest-extra',
        ),
        isFalse,
      );
    });

    test('duplicate movement candidates are not used as filler', () {
      final builder = _standardBuilder()
        ..addStrength(
          id: 'duplicate-press',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: 'chest_primary',
          price: 1,
          priority: 10,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 10);

      expect(
        result.selections.any(
          (selection) => selection.productId == 'duplicate-press',
        ),
        isFalse,
      );
    });

    test('selected Premier series are never broadened', () {
      final builder = _PoolBuilder()
        ..addStrength(
          id: 'apn',
          code: 'APN01',
          brand: 'Premier',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: 'press',
          price: 100,
        )
        ..addStrength(
          id: 'pxn',
          code: 'PXN01',
          brand: 'Premier',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.pinLoaded,
          movementKey: 'row',
          price: 1,
        )
        ..addStrength(
          id: 'apl',
          code: 'APL01',
          brand: 'Premier',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.plateLoaded,
          movementKey: 'fly',
          price: 100,
        )
        ..addStrength(
          id: 'pxl',
          code: 'PXL01',
          brand: 'Premier',
          area: QuickQuoteStrengthArea.chest,
          loadType: QuickQuoteLoadType.plateLoaded,
          movementKey: 'pull',
          price: 1,
        );
      final request = _premierRequest(10000);
      final pool = builder.build(request: request);
      final result = optimizer.optimize(request: request, candidatePool: pool);

      expect(
        result.selections
            .where(
              (selection) => selection.kind == QuickQuoteSelectionKind.strength,
            )
            .map((selection) => selection.productId),
        ['apn', 'apl'],
      );
    });
  });

  group('multifunction expansion', () {
    test('selects exactly one Functional Trainer role', () {
      final builder = _standardBuilder()
        ..addMultifunction(
          id: 'functional-a',
          role: QuickQuoteMultifunctionRole.functionalTrainer,
          price: 50,
        )
        ..addMultifunction(
          id: 'functional-b',
          role: QuickQuoteMultifunctionRole.functionalTrainer,
          price: 60,
        );
      final result = _optimize(optimizer, builder.build(), 100000);

      expect(
        result.selections.where(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.functionalTrainer,
        ),
        hasLength(1),
      );
      expect(
        result.selectedMultifunctionRoles.where(
          (role) => role == QuickQuoteMultifunctionRole.functionalTrainer,
        ),
        hasLength(1),
      );
    });

    test('selects exactly one Multi Station', () {
      final builder = _standardBuilder()
        ..addMultifunction(
          id: 'multi-4',
          role: QuickQuoteMultifunctionRole.multiStation,
          price: 40,
          stationCount: 4,
        )
        ..addMultifunction(
          id: 'multi-8',
          role: QuickQuoteMultifunctionRole.multiStation,
          price: 80,
          stationCount: 8,
        );
      final result = _optimize(optimizer, builder.build(), 100000);

      expect(
        result.selections.where(
          (selection) => selection.kind == QuickQuoteSelectionKind.multiStation,
        ),
        hasLength(1),
      );
    });

    test('Multi Station size alternatives remain mutually exclusive', () {
      final builder = _standardBuilder()
        ..addMultifunction(
          id: 'multi-2',
          role: QuickQuoteMultifunctionRole.multiStation,
          price: 10,
          stationCount: 2,
        )
        ..addMultifunction(
          id: 'multi-4',
          role: QuickQuoteMultifunctionRole.multiStation,
          price: 20,
          stationCount: 4,
        )
        ..addMultifunction(
          id: 'multi-8',
          role: QuickQuoteMultifunctionRole.multiStation,
          price: 30,
          stationCount: 8,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 10);

      final stations = result.selections.where(
        (selection) => selection.kind == QuickQuoteSelectionKind.multiStation,
      );
      expect(stations, hasLength(1));
      expect(stations.single.candidate.stationCount, 2);
    });
  });

  group('plate and dumbbell upgrades', () {
    test('never mixes weight plate families', () {
      final builder = _standardBuilder()..addPlateFamily('plate-b', price: 90);
      final result = _optimize(optimizer, builder.build(), 100000);

      final families = result.selections
          .where(
            (selection) =>
                selection.kind == QuickQuoteSelectionKind.weightPlate,
          )
          .map((selection) => selection.candidate.mapping.familyKey)
          .toSet();
      expect(families, hasLength(1));
    });

    test('8 to 12 replaces the plate tier', () {
      final pool = _standardBuilder().build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 1600);

      expect(result.plateConfiguration.quantityEach, 12);
      expect(
        result.selections
            .where(
              (selection) =>
                  selection.kind == QuickQuoteSelectionKind.weightPlate,
            )
            .map((selection) => selection.quantity)
            .toSet(),
        {12},
      );
    });

    test('12 to 15 replaces the plate tier', () {
      final pool = _standardBuilder().build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 2800);

      expect(result.plateConfiguration.quantityEach, 15);
      expect(
        result.selections
            .where(
              (selection) =>
                  selection.kind == QuickQuoteSelectionKind.weightPlate,
            )
            .map((selection) => selection.quantity)
            .toSet(),
        {15},
      );
    });

    test('half dumbbell set adds exactly one additional rack', () {
      final pool = _standardBuilder(includeHalfSet: true).build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 150);

      expect(result.dumbbellConfiguration.hasHalfSet, isTrue);
      expect(result.dumbbellConfiguration.rackQuantity, 3);
    });

    test('never mixes incompatible dumbbell families', () {
      final builder = _standardBuilder(includeHalfSet: true)
        ..addDumbbellFamily(
          'dumbbell-b',
          includeFull: false,
          includeHalf: true,
          setPrice: 1,
          rackPrice: 1,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 150);

      final families = result.selections
          .where(
            (selection) =>
                selection.kind == QuickQuoteSelectionKind.dumbbellFullSet ||
                selection.kind == QuickQuoteSelectionKind.dumbbellHalfSet ||
                selection.kind == QuickQuoteSelectionKind.dumbbellRack,
          )
          .map((selection) => selection.candidate.mapping.familyKey)
          .toSet();
      expect(families, {'dumbbell-a'});
    });
  });

  group('closest practical budget', () {
    test('selects a slight over-target result when it is closer', () {
      final builder = _standardBuilder()
        ..addMultifunction(
          id: 'smith',
          role: QuickQuoteMultifunctionRole.smithMachine,
          price: 13,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 10);

      expect(result.status, QuickQuoteBudgetStatus.overTarget);
      expect(result.grandTotal, minimum + 13);
      expect(result.absoluteDifference, 3);
    });

    test('keeps the under-target result when overspend is farther', () {
      final builder = _standardBuilder()
        ..addMultifunction(
          id: 'smith',
          role: QuickQuoteMultifunctionRole.smithMachine,
          price: 20,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 5);

      expect(result.status, QuickQuoteBudgetStatus.underTarget);
      expect(result.grandTotal, minimum);
    });

    test('equal-distance tie prefers the under-target portfolio', () {
      final builder = _standardBuilder()
        ..addMultifunction(
          id: 'smith',
          role: QuickQuoteMultifunctionRole.smithMachine,
          price: 10,
        );
      final pool = builder.build();
      final minimum = _minimumResult(optimizer, pool).grandTotal;
      final result = _optimize(optimizer, pool, minimum + 5);

      expect(result.status, QuickQuoteBudgetStatus.underTarget);
      expect(result.grandTotal, minimum);
    });

    test('does not add an expensive equivalent model merely to spend', () {
      final builder = _standardBuilder()
        ..addCardio(
          id: 'treadmill-expensive',
          role: QuickQuoteCardioRole.treadmill,
          price: 1000,
          priority: 10,
        );
      final result = _optimize(optimizer, builder.build(), 100000);

      expect(
        result.selections.any(
          (selection) => selection.productId == 'treadmill-expensive',
        ),
        isFalse,
      );
    });

    test(
      'adds a unique extra strength movement when it improves closeness',
      () {
        final builder = _standardBuilder()
          ..addStrength(
            id: 'unique-extra',
            area: QuickQuoteStrengthArea.chest,
            loadType: QuickQuoteLoadType.pinLoaded,
            movementKey: 'unique_extra',
            price: 10,
            priority: 10,
          );
        final pool = builder.build();
        final minimum = _minimumResult(optimizer, pool).grandTotal;
        final result = _optimize(optimizer, pool, minimum + 10);

        expect(
          result.selections.any(
            (selection) =>
                selection.productId == 'unique-extra' &&
                selection.kind == QuickQuoteSelectionKind.additionalStrength,
          ),
          isTrue,
        );
      },
    );
  });

  group('VAT and output', () {
    test('VAT-inclusive total matches QuotationCalculator', () {
      final pool = _standardBuilder(taxable: true).build();
      final result = _minimumResult(optimizer, pool);
      final items = [
        for (var index = 0; index < result.selections.length; index++)
          QuotationLineItemFactory.fromProduct(
            result.selections[index].candidate.product,
            quantity: result.selections[index].quantity,
            id: 'test-$index',
          ),
      ];
      const charges = QuotationCharges();

      expect(result.subtotal, QuotationCalculator.calculateSubtotal(items));
      expect(result.vat, QuotationCalculator.calculateVAT(items, charges));
      expect(
        result.grandTotal,
        QuotationCalculator.calculateGrandTotal(items, charges),
      );
    });

    test('VAT-exempt products match existing calculator behavior', () {
      final pool = _standardBuilder(taxable: false).build();
      final result = _minimumResult(optimizer, pool);

      expect(result.vat, 0);
      expect(result.grandTotal, result.subtotal);
    });

    test('final selections use the locked deterministic output order', () {
      final builder = _standardBuilder(
        includeCounterparts: true,
        includeMultifunction: true,
        includeHalfSet: true,
        includeUniqueExtra: true,
      );
      final result = _optimize(optimizer, builder.build(), 1000000);
      final groups = result.selections.map(_outputGroup).toList();

      expect(groups, orderedEquals([...groups]..sort()));
      expect(
        result.selections
            .where(
              (selection) => selection.kind == QuickQuoteSelectionKind.cardio,
            )
            .map((selection) => selection.cardioRole),
        QuickQuoteCardioRole.values,
      );
      final baseStrength = result.selections.where(
        (selection) => selection.kind == QuickQuoteSelectionKind.strength,
      );
      expect(
        baseStrength.map((selection) => selection.strengthArea).toSet(),
        QuickQuoteStrengthArea.values.toSet(),
      );
      expect(
        result.selections.last.kind,
        QuickQuoteSelectionKind.additionalStrength,
      );
    });
  });
}

QuickQuoteRequest _request(double targetBudget) =>
    QuickQuoteRequest(targetBudget: targetBudget, strengthBrand: 'Matrix');

QuickQuoteRequest _premierRequest(double targetBudget) => QuickQuoteRequest(
  targetBudget: targetBudget,
  strengthBrand: 'Premier',
  premierPinSeriesPrefix: 'APN',
  premierPlateSeriesPrefix: 'APL',
);

QuickQuoteResult _optimize(
  QuickQuoteOptimizer optimizer,
  QuickQuoteCandidatePool pool,
  double target,
) => optimizer.optimize(request: _request(target), candidatePool: pool);

QuickQuoteResult _minimumResult(
  QuickQuoteOptimizer optimizer,
  QuickQuoteCandidatePool pool,
) => _optimize(optimizer, pool, 1);

List<String> _signature(QuickQuoteResult result) => result.selections
    .map(
      (selection) =>
          '${selection.kind.name}:${selection.productId}:'
          '${selection.quantity}',
    )
    .toList();

int _outputGroup(QuickQuoteSelection selection) => switch (selection.kind) {
  QuickQuoteSelectionKind.cardio => 0,
  QuickQuoteSelectionKind.strength => 1,
  QuickQuoteSelectionKind.smithMachine => 2,
  QuickQuoteSelectionKind.functionalTrainer => 3,
  QuickQuoteSelectionKind.multiStation => 4,
  QuickQuoteSelectionKind.dumbbellFullSet ||
  QuickQuoteSelectionKind.dumbbellHalfSet => 5,
  QuickQuoteSelectionKind.dumbbellRack => 6,
  QuickQuoteSelectionKind.weightPlate => 7,
  QuickQuoteSelectionKind.additionalStrength => 8,
};

QuickQuoteCandidatePool _reversedPool(QuickQuoteCandidatePool source) {
  final strength =
      <QuickQuoteStrengthPoolKey, QuickQuoteStrengthCandidatePool>{};
  for (final entry in source.strengthCandidates.entries) {
    strength[entry.key] = QuickQuoteStrengthCandidatePool(
      key: entry.key,
      candidates: entry.value.candidates.reversed.toList(),
      movementGroups: {
        for (final movement in entry.value.movementGroups.entries)
          movement.key: movement.value.reversed.toList(),
      },
    );
  }
  return QuickQuoteCandidatePool(
    cardioCandidates: {
      for (final entry in source.cardioCandidates.entries)
        entry.key: entry.value.reversed.toList(),
    },
    strengthCandidates: strength,
    multifunctionCandidates: {
      for (final entry in source.multifunctionCandidates.entries)
        entry.key: entry.value.reversed.toList(),
    },
    multiStationExclusivityGroup: QuickQuoteExclusiveCandidateGroup(
      key: source.multiStationExclusivityGroup.key,
      candidates: source.multiStationExclusivityGroup.candidates.reversed
          .toList(),
    ),
    dumbbellFullSetBundles: source.dumbbellFullSetBundles.reversed.toList(),
    dumbbellHalfSetBundles: source.dumbbellHalfSetBundles.reversed.toList(),
    weightPlateBundles: source.weightPlateBundles.reversed.toList(),
    issues: source.issues,
  );
}

_PoolBuilder _standardBuilder({
  bool includeCounterparts = false,
  bool includeMultifunction = false,
  bool includeHalfSet = false,
  bool includeUniqueExtra = false,
  bool taxable = false,
}) {
  final builder = _PoolBuilder(defaultTaxable: taxable);
  for (final role in QuickQuoteCardioRole.values) {
    builder.addCardio(
      id: 'cardio-${role.mappingValue}',
      role: role,
      price: 100,
    );
  }
  for (final area in QuickQuoteStrengthArea.values) {
    builder.addStrength(
      id: 'strength-${area.databaseValue}-pin',
      area: area,
      loadType: QuickQuoteLoadType.pinLoaded,
      movementKey: '${area.databaseValue}_primary',
      price: 100,
      priority: 0,
    );
    if (includeCounterparts) {
      builder.addStrength(
        id: 'strength-${area.databaseValue}-plate',
        area: area,
        loadType: QuickQuoteLoadType.plateLoaded,
        movementKey: '${area.databaseValue}_secondary',
        price: 100,
        priority: 1,
      );
    }
  }
  builder
    ..addDumbbellFamily(
      'dumbbell-a',
      includeFull: true,
      includeHalf: includeHalfSet,
      setPrice: 100,
      rackPrice: 50,
    )
    ..addPlateFamily('plate-a', price: 100);

  if (includeMultifunction) {
    builder
      ..addMultifunction(
        id: 'smith',
        role: QuickQuoteMultifunctionRole.smithMachine,
        price: 50,
      )
      ..addMultifunction(
        id: 'functional',
        role: QuickQuoteMultifunctionRole.functionalTrainer,
        price: 60,
      )
      ..addMultifunction(
        id: 'multi',
        role: QuickQuoteMultifunctionRole.multiStation,
        price: 70,
        stationCount: 4,
      );
  }
  if (includeUniqueExtra) {
    builder.addStrength(
      id: 'strength-unique-extra',
      area: QuickQuoteStrengthArea.chest,
      loadType: QuickQuoteLoadType.pinLoaded,
      movementKey: 'unique_extra',
      price: 10,
      priority: 10,
    );
  }
  return builder;
}

class _PoolBuilder {
  _PoolBuilder({this.defaultTaxable = false});

  final bool defaultTaxable;
  final List<Product> _products = [];
  final List<QuickQuoteProductMapping> _mappings = [];

  void addCardio({
    required String id,
    required QuickQuoteCardioRole role,
    required double price,
    int priority = 0,
    bool? taxable,
  }) {
    _addProduct(id: id, price: price, taxable: taxable);
    _mappings.add(
      _mapping(
        id: id,
        section: QuickQuoteSection.cardio,
        roleKey: role.mappingValue,
        priority: priority,
      ),
    );
  }

  void addStrength({
    required String id,
    String? code,
    String brand = 'Matrix',
    required QuickQuoteStrengthArea area,
    required QuickQuoteLoadType loadType,
    required String movementKey,
    required double price,
    int priority = 0,
    bool? taxable,
  }) {
    _addProduct(
      id: id,
      code: code,
      brand: brand,
      price: price,
      taxable: taxable,
    );
    _mappings.add(
      _mapping(
        id: id,
        section: QuickQuoteSection.strength,
        roleKey: 'strength_machine',
        area: area,
        loadType: loadType,
        movementKey: movementKey,
        priority: priority,
      ),
    );
  }

  void addMultifunction({
    required String id,
    required QuickQuoteMultifunctionRole role,
    required double price,
    int? stationCount,
    int priority = 0,
    bool? taxable,
  }) {
    _addProduct(id: id, price: price, taxable: taxable);
    _mappings.add(
      _mapping(
        id: id,
        section: QuickQuoteSection.multifunction,
        roleKey: role.mappingValue,
        stationCount: stationCount,
        priority: priority,
      ),
    );
  }

  void addDumbbellFamily(
    String familyKey, {
    required bool includeFull,
    required bool includeHalf,
    required double setPrice,
    required double rackPrice,
    bool? taxable,
  }) {
    if (includeFull) {
      final id = '$familyKey-full';
      _addProduct(id: id, price: setPrice, taxable: taxable);
      _mappings.add(
        _mapping(
          id: id,
          section: QuickQuoteSection.dumbbell,
          roleKey: quickQuoteDumbbellFullSetRole,
          familyKey: familyKey,
        ),
      );
    }
    if (includeHalf) {
      final id = '$familyKey-half';
      _addProduct(id: id, price: setPrice, taxable: taxable);
      _mappings.add(
        _mapping(
          id: id,
          section: QuickQuoteSection.dumbbell,
          roleKey: quickQuoteDumbbellHalfSetRole,
          familyKey: familyKey,
        ),
      );
    }
    final rackId = '$familyKey-rack';
    _addProduct(id: rackId, price: rackPrice, taxable: taxable);
    _mappings.add(
      _mapping(
        id: rackId,
        section: QuickQuoteSection.dumbbellRack,
        roleKey: quickQuoteDumbbellRackRole,
        familyKey: familyKey,
      ),
    );
  }

  void addPlateFamily(
    String familyKey, {
    required double price,
    bool? taxable,
  }) {
    for (final weight in quickQuoteRequiredPlateWeightsKg) {
      final id = '$familyKey-$weight';
      _addProduct(id: id, price: price, taxable: taxable);
      _mappings.add(
        _mapping(
          id: id,
          section: QuickQuoteSection.weightPlate,
          roleKey: quickQuoteWeightPlateRole,
          familyKey: familyKey,
          plateWeightKg: weight,
        ),
      );
    }
  }

  QuickQuoteCandidatePool build({QuickQuoteRequest? request}) {
    return QuickQuoteCandidatePreparer().prepare(
      request: request ?? _request(1000000),
      products: _products,
      mappings: _mappings,
    );
  }

  void _addProduct({
    required String id,
    String? code,
    String brand = 'Any',
    required double price,
    bool? taxable,
  }) {
    _products.add(
      Product(
        id: id,
        productCode: code ?? id,
        name: id,
        category: 'Mapped',
        brand: brand,
        sellingPrice: price,
        isVatApplicable: taxable ?? defaultTaxable,
        createdAt: DateTime.utc(2026, 10),
        updatedAt: DateTime.utc(2026, 10),
      ),
    );
  }

  QuickQuoteProductMapping _mapping({
    required String id,
    required QuickQuoteSection section,
    required String roleKey,
    QuickQuoteStrengthArea? area,
    QuickQuoteLoadType? loadType,
    String? movementKey,
    String? familyKey,
    double? plateWeightKg,
    int? stationCount,
    int priority = 0,
  }) => QuickQuoteProductMapping(
    productId: id,
    status: QuickQuoteMappingStatus.eligible,
    section: section,
    roleKey: roleKey,
    strengthArea: area,
    loadType: loadType,
    movementKey: movementKey,
    familyKey: familyKey,
    plateWeightKg: plateWeightKg,
    stationCount: stationCount,
    selectionPriority: priority,
    upgradePriority: priority,
    updatedAt: DateTime.utc(2026, 10),
  );
}
