import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_candidate_preparer.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_generation_issue.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_request.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final preparer = QuickQuoteCandidatePreparer();

  group('base filtering', () {
    test('inactive products are excluded', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [_product(id: 'inactive', isActive: false)],
        mappings: [_cardioMapping('inactive')],
      );

      expect(pool.cardioCandidates[QuickQuoteCardioRole.treadmill], isEmpty);
    });

    test('manual excluded mappings are excluded', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [_product(id: 'manual')],
        mappings: [
          _cardioMapping(
            'manual',
            status: QuickQuoteMappingStatus.manualExcluded,
          ),
        ],
      );

      expect(pool.cardioCandidates[QuickQuoteCardioRole.treadmill], isEmpty);
    });

    test('zero and negative selling prices are excluded', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'zero', sellingPrice: 0),
          _product(id: 'negative', sellingPrice: -1),
        ],
        mappings: [_cardioMapping('zero'), _cardioMapping('negative')],
      );

      expect(pool.cardioCandidates[QuickQuoteCardioRole.treadmill], isEmpty);
    });

    test('cardio selections can constrain product and brand', () {
      final pool = preparer.prepare(
        request: _request(
          cardioSelections: const {
            QuickQuoteCardioRole.treadmill: QuickQuoteCardioSelection(
              productId: 'selected',
              brand: 'Cardio Brand',
            ),
          },
        ),
        products: [
          _product(id: 'selected', brand: 'cardio brand'),
          _product(id: 'other', brand: 'Cardio Brand'),
        ],
        mappings: [_cardioMapping('selected'), _cardioMapping('other')],
      );

      expect(
        pool.cardioCandidates[QuickQuoteCardioRole.treadmill]!.map(
          (candidate) => candidate.productId,
        ),
        ['selected'],
      );
    });
  });

  group('cardio candidates', () {
    test('only the five approved mapping roles are accepted', () {
      final products = [
        _product(id: 'treadmill'),
        _product(id: 'rower', category: 'Home Use Cardio'),
        _product(id: 'skierg'),
        _product(id: 'stair'),
      ];
      final mappings = [
        _cardioMapping('treadmill'),
        _cardioMapping('rower', roleKey: 'rower'),
        _cardioMapping('skierg', roleKey: 'skierg'),
        _cardioMapping('stair', roleKey: 'stair_master'),
      ];

      final pool = preparer.prepare(
        request: _request(),
        products: products,
        mappings: mappings,
      );

      final cardioIds = pool.cardioCandidates.values
          .expand((candidates) => candidates)
          .map((candidate) => candidate.productId)
          .toList();
      expect(cardioIds, ['treadmill']);
    });
  });

  group('strength candidates', () {
    test('builds separate area and load pools', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'chest-pin', brand: 'Matrix'),
          _product(id: 'legs-plate', brand: 'Matrix'),
        ],
        mappings: [
          _strengthMapping(
            'chest-pin',
            area: QuickQuoteStrengthArea.chest,
            loadType: QuickQuoteLoadType.pinLoaded,
          ),
          _strengthMapping(
            'legs-plate',
            area: QuickQuoteStrengthArea.legs,
            loadType: QuickQuoteLoadType.plateLoaded,
          ),
        ],
      );

      expect(
        pool
            .strengthPool(
              QuickQuoteStrengthArea.chest,
              QuickQuoteLoadType.pinLoaded,
            )
            .candidates
            .single
            .productId,
        'chest-pin',
      );
      expect(
        pool
            .strengthPool(
              QuickQuoteStrengthArea.legs,
              QuickQuoteLoadType.plateLoaded,
            )
            .candidates
            .single
            .productId,
        'legs-plate',
      );
    });

    test('strength brand is a hard constraint', () {
      final pool = preparer.prepare(
        request: _request(strengthBrand: 'Matrix'),
        products: [
          _product(id: 'matrix', brand: 'Matrix'),
          _product(id: 'other', brand: 'Other'),
        ],
        mappings: [_strengthMapping('matrix'), _strengthMapping('other')],
      );

      expect(
        pool
            .strengthPool(
              QuickQuoteStrengthArea.chest,
              QuickQuoteLoadType.pinLoaded,
            )
            .candidates
            .map((candidate) => candidate.productId),
        ['matrix'],
      );
    });

    test('Premier pin series filtering uses the selected series', () {
      final pool = preparer.prepare(
        request: _premierRequest(pinPrefix: 'APN'),
        products: [
          _product(id: 'apn', code: 'APN01', brand: 'Premier'),
          _product(id: 'pxn', code: 'PXN01', brand: 'Premier'),
          _product(id: 'epn', code: 'EPN01', brand: 'Premier'),
        ],
        mappings: [
          _strengthMapping('apn'),
          _strengthMapping('pxn'),
          _strengthMapping('epn'),
        ],
      );

      expect(
        pool
            .strengthPool(
              QuickQuoteStrengthArea.chest,
              QuickQuoteLoadType.pinLoaded,
            )
            .candidates
            .map((candidate) => candidate.productId),
        ['apn'],
      );
    });

    test('Premier plate series filtering uses the selected series', () {
      final pool = preparer.prepare(
        request: _premierRequest(platePrefix: 'APL'),
        products: [
          _product(id: 'apl', code: 'APL01', brand: 'Premier'),
          _product(id: 'pxl', code: 'PXL01', brand: 'Premier'),
        ],
        mappings: [
          _strengthMapping('apl', loadType: QuickQuoteLoadType.plateLoaded),
          _strengthMapping('pxl', loadType: QuickQuoteLoadType.plateLoaded),
        ],
      );

      expect(
        pool
            .strengthPool(
              QuickQuoteStrengthArea.chest,
              QuickQuoteLoadType.plateLoaded,
            )
            .candidates
            .map((candidate) => candidate.productId),
        ['apl'],
      );
    });

    test('selected series are never silently broadened', () {
      final pool = preparer.prepare(
        request: _premierRequest(pinPrefix: 'EPN'),
        products: [
          _product(id: 'apn', code: 'APN01', brand: 'Premier'),
          _product(id: 'pxn', code: 'PXN01', brand: 'Premier'),
        ],
        mappings: [_strengthMapping('apn'), _strengthMapping('pxn')],
      );

      expect(
        pool
            .strengthPool(
              QuickQuoteStrengthArea.chest,
              QuickQuoteLoadType.pinLoaded,
            )
            .candidates,
        isEmpty,
      );
      expect(
        pool.issues.where(
          (issue) =>
              issue.type ==
                  QuickQuoteGenerationIssueType.missingStrengthPinCandidate &&
              issue.strengthArea == QuickQuoteStrengthArea.chest,
        ),
        hasLength(1),
      );
    });

    test('TQN and TQL cannot become Premier series selections', () {
      expect(() => _premierRequest(pinPrefix: 'TQN'), throwsArgumentError);
      expect(() => _premierRequest(platePrefix: 'TQL'), throwsArgumentError);

      final pool = preparer.prepare(
        request: _premierRequest(),
        products: [
          _product(id: 'tqn', code: 'TQN01', brand: 'Premier'),
          _product(id: 'tql', code: 'TQL01', brand: 'Premier'),
        ],
        mappings: [
          _strengthMapping('tqn'),
          _strengthMapping('tql', loadType: QuickQuoteLoadType.plateLoaded),
        ],
      );
      expect(
        pool.strengthCandidates.values.expand(
          (strengthPool) => strengthPool.candidates,
        ),
        isEmpty,
      );
    });

    test('same movement candidates remain deterministically grouped', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'press-b', code: 'B', brand: 'Matrix'),
          _product(id: 'fly', code: 'C', brand: 'Matrix'),
          _product(id: 'press-a', code: 'A', brand: 'Matrix'),
        ],
        mappings: [
          _strengthMapping('press-b', movementKey: 'press'),
          _strengthMapping('fly', movementKey: 'fly'),
          _strengthMapping('press-a', movementKey: 'press'),
        ],
      );
      final strengthPool = pool.strengthPool(
        QuickQuoteStrengthArea.chest,
        QuickQuoteLoadType.pinLoaded,
      );

      expect(strengthPool.movementGroups.keys, ['fly', 'press']);
      expect(
        strengthPool.movementGroups['press']!.map(
          (candidate) => candidate.productId,
        ),
        ['press-a', 'press-b'],
      );
    });
  });

  group('deterministic ordering', () {
    test('sorts by priority, price, normalized code, then product ID', () {
      final products = [
        _product(id: 'priority', code: 'Z', sellingPrice: 100),
        _product(id: 'price', code: 'Z', sellingPrice: 50),
        _product(id: 'code-b', code: 'b', sellingPrice: 100),
        _product(id: 'id-z', code: 'a', sellingPrice: 100),
        _product(id: 'id-a', code: 'A', sellingPrice: 100),
      ];
      final mappings = [
        _cardioMapping('priority', selectionPriority: 0),
        _cardioMapping('price', selectionPriority: 1),
        _cardioMapping('code-b', selectionPriority: 1),
        _cardioMapping('id-z', selectionPriority: 1),
        _cardioMapping('id-a', selectionPriority: 1),
      ];

      final pool = preparer.prepare(
        request: _request(),
        products: products.reversed,
        mappings: mappings.reversed,
      );

      expect(
        pool.cardioCandidates[QuickQuoteCardioRole.treadmill]!.map(
          (candidate) => candidate.productId,
        ),
        ['priority', 'price', 'id-a', 'id-z', 'code-b'],
      );
    });
  });

  group('multifunction candidates', () {
    test(
      'functional trainer, DAP, and cable products share one mapped role',
      () {
        final pool = preparer.prepare(
          request: _request(),
          products: [
            _product(id: 'functional', name: 'Functional Trainer'),
            _product(id: 'dap', name: 'DAP'),
            _product(id: 'cable', name: 'Cable Crossover'),
          ],
          mappings: [
            _multifunctionMapping('functional', 'functional_trainer'),
            _multifunctionMapping('dap', 'functional_trainer'),
            _multifunctionMapping('cable', 'functional_trainer'),
          ],
        );

        expect(
          pool
              .multifunctionCandidates[QuickQuoteMultifunctionRole
                  .functionalTrainer]!
              .map((candidate) => candidate.productId),
          ['cable', 'dap', 'functional'],
        );
      },
    );

    test('multi-station sizes are retained and mutually exclusive', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'station-4'),
          _product(id: 'station-8'),
        ],
        mappings: [
          _multifunctionMapping('station-4', 'multi_station', stationCount: 4),
          _multifunctionMapping('station-8', 'multi_station', stationCount: 8),
        ],
      );

      final candidates = pool
          .multifunctionCandidates[QuickQuoteMultifunctionRole.multiStation]!;
      expect(candidates.map((candidate) => candidate.stationCount), [4, 8]);
      expect(
        pool.multiStationExclusivityGroup.key,
        quickQuoteMultiStationExclusivityKey,
      );
      expect(pool.multiStationExclusivityGroup.candidates, candidates);
    });
  });

  group('dumbbell bundles', () {
    test('full set bundle contains one set and two compatible racks', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'full'),
          _product(id: 'rack'),
        ],
        mappings: [
          _dumbbellMapping(
            'full',
            roleKey: quickQuoteDumbbellFullSetRole,
            familyKey: 'family-a',
          ),
          _dumbbellMapping(
            'rack',
            roleKey: quickQuoteDumbbellRackRole,
            familyKey: 'family-a',
            section: QuickQuoteSection.dumbbellRack,
          ),
        ],
      );

      final bundle = pool.dumbbellFullSetBundles.single;
      expect(bundle.familyKey, 'family-a');
      expect(bundle.setCandidate.productId, 'full');
      expect(bundle.rackCandidate.productId, 'rack');
      expect(bundle.lines.map((line) => line.quantity), [1, 2]);
    });

    test('optional half set bundle contains one set and one rack', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'half'),
          _product(id: 'rack'),
        ],
        mappings: [
          _dumbbellMapping(
            'half',
            roleKey: quickQuoteDumbbellHalfSetRole,
            familyKey: 'family-a',
          ),
          _dumbbellMapping(
            'rack',
            roleKey: quickQuoteDumbbellRackRole,
            familyKey: 'family-a',
            section: QuickQuoteSection.dumbbellRack,
          ),
        ],
      );

      final bundle = pool.dumbbellHalfSetBundles.single;
      expect(bundle.kind, QuickQuoteDumbbellBundleKind.optionalHalfSet);
      expect(bundle.lines.map((line) => line.quantity), [1, 1]);
    });

    test('incompatible dumbbell families never form a bundle', () {
      final pool = preparer.prepare(
        request: _request(),
        products: [
          _product(id: 'full-a'),
          _product(id: 'rack-b'),
        ],
        mappings: [
          _dumbbellMapping(
            'full-a',
            roleKey: quickQuoteDumbbellFullSetRole,
            familyKey: 'family-a',
          ),
          _dumbbellMapping(
            'rack-b',
            roleKey: quickQuoteDumbbellRackRole,
            familyKey: 'family-b',
            section: QuickQuoteSection.dumbbellRack,
          ),
        ],
      );

      expect(pool.dumbbellFullSetBundles, isEmpty);
      expect(
        pool.issues.where(
          (issue) =>
              issue.type ==
                  QuickQuoteGenerationIssueType
                      .missingDumbbellRackCompatibility &&
              issue.familyKey == 'family-a',
        ),
        hasLength(1),
      );
    });
  });

  group('weight plate bundles', () {
    test('complete families require all four approved weights', () {
      final pool = preparer.prepare(
        request: _request(),
        products: _plateProducts(include20Kg: true),
        mappings: _plateMappings(include20Kg: true),
      );

      expect(pool.weightPlateBundles, hasLength(3));
      expect(
        pool.weightPlateBundles.first.plateCandidates.map(
          (candidate) => candidate.mapping.plateWeightKg,
        ),
        [2.5, 5, 10, 20],
      );
    });

    test('creates exactly the 8, 12, and 15 quantity tiers', () {
      final pool = preparer.prepare(
        request: _request(),
        products: _plateProducts(include20Kg: true),
        mappings: _plateMappings(include20Kg: true),
      );

      expect(
        pool.weightPlateBundles.map((bundle) => bundle.quantityEach),
        quickQuotePlateQuantityTiers,
      );
      for (final bundle in pool.weightPlateBundles) {
        expect(bundle.lines.map((line) => line.quantity).toSet(), {
          bundle.quantityEach,
        });
        expect(
          bundle.exclusivityKey,
          quickQuoteWeightPlateBundleExclusivityKey,
        );
      }
    });

    test('incomplete families are excluded from automatic bundles', () {
      final pool = preparer.prepare(
        request: _request(),
        products: _plateProducts(include20Kg: false),
        mappings: _plateMappings(include20Kg: false),
      );

      expect(pool.weightPlateBundles, isEmpty);
      expect(
        pool.issues.where(
          (issue) =>
              issue.type ==
                  QuickQuoteGenerationIssueType.missingCompletePlateFamily &&
              issue.familyKey == 'plate-family',
        ),
        hasLength(1),
      );
    });
  });

  group('availability and budget foundation', () {
    test('missing-role diagnostics report exact unavailable pools', () {
      final pool = preparer.prepare(
        request: _request(),
        products: const [],
        mappings: const [],
      );

      expect(
        pool.issues
            .where(
              (issue) =>
                  issue.type == QuickQuoteGenerationIssueType.missingCardioRole,
            )
            .map((issue) => issue.cardioRole),
        QuickQuoteCardioRole.values,
      );
      expect(
        pool.issues.where(
          (issue) =>
              issue.type ==
              QuickQuoteGenerationIssueType.missingStrengthPinCandidate,
        ),
        hasLength(7),
      );
      expect(
        pool.issues.where(
          (issue) =>
              issue.type ==
              QuickQuoteGenerationIssueType.missingStrengthPlateCandidate,
        ),
        hasLength(7),
      );
      expect(
        pool.issues.where(
          (issue) =>
              issue.type ==
              QuickQuoteGenerationIssueType.unavailableMultifunctionRole,
        ),
        hasLength(3),
      );
      expect(pool.issues, hasLength(24));
    });

    test('target budget must be positive', () {
      expect(() => _request(targetBudget: 0), throwsArgumentError);
      expect(() => _request(targetBudget: -1), throwsArgumentError);
    });

    test('target budget is not encoded as a hard candidate ceiling', () {
      final pool = preparer.prepare(
        request: _request(targetBudget: 1),
        products: [_product(id: 'expensive', sellingPrice: 1000000)],
        mappings: [_cardioMapping('expensive')],
      );

      expect(
        pool.cardioCandidates[QuickQuoteCardioRole.treadmill]!.single.productId,
        'expensive',
      );
    });
  });
}

QuickQuoteRequest _request({
  double targetBudget = 100000,
  String strengthBrand = 'Matrix',
  Map<QuickQuoteCardioRole, QuickQuoteCardioSelection> cardioSelections =
      const {},
}) => QuickQuoteRequest(
  targetBudget: targetBudget,
  strengthBrand: strengthBrand,
  cardioSelections: cardioSelections,
);

QuickQuoteRequest _premierRequest({
  String pinPrefix = 'APN',
  String platePrefix = 'APL',
}) => QuickQuoteRequest(
  targetBudget: 100000,
  strengthBrand: 'Premier',
  premierPinSeriesPrefix: pinPrefix,
  premierPlateSeriesPrefix: platePrefix,
);

Product _product({
  required String id,
  String? code,
  String name = 'Mapped product',
  String category = 'Ignored',
  String brand = 'Any',
  double sellingPrice = 100,
  bool isActive = true,
}) => Product(
  id: id,
  productCode: code ?? id,
  name: name,
  category: category,
  brand: brand,
  sellingPrice: sellingPrice,
  isActive: isActive,
  createdAt: DateTime.utc(2026, 10),
  updatedAt: DateTime.utc(2026, 10),
);

QuickQuoteProductMapping _cardioMapping(
  String productId, {
  String roleKey = 'treadmill',
  QuickQuoteMappingStatus status = QuickQuoteMappingStatus.eligible,
  int selectionPriority = 100,
}) => _mapping(
  productId,
  status: status,
  section: QuickQuoteSection.cardio,
  roleKey: roleKey,
  selectionPriority: selectionPriority,
);

QuickQuoteProductMapping _strengthMapping(
  String productId, {
  QuickQuoteStrengthArea area = QuickQuoteStrengthArea.chest,
  QuickQuoteLoadType loadType = QuickQuoteLoadType.pinLoaded,
  String movementKey = 'press',
}) => _mapping(
  productId,
  section: QuickQuoteSection.strength,
  roleKey: 'strength_role',
  strengthArea: area,
  loadType: loadType,
  movementKey: movementKey,
);

QuickQuoteProductMapping _multifunctionMapping(
  String productId,
  String roleKey, {
  int? stationCount,
}) => _mapping(
  productId,
  section: QuickQuoteSection.multifunction,
  roleKey: roleKey,
  stationCount: stationCount,
);

QuickQuoteProductMapping _dumbbellMapping(
  String productId, {
  required String roleKey,
  required String familyKey,
  QuickQuoteSection section = QuickQuoteSection.dumbbell,
}) => _mapping(
  productId,
  section: section,
  roleKey: roleKey,
  familyKey: familyKey,
);

List<Product> _plateProducts({required bool include20Kg}) => [
  _product(id: 'plate-2-5'),
  _product(id: 'plate-5'),
  _product(id: 'plate-10'),
  if (include20Kg) _product(id: 'plate-20'),
];

List<QuickQuoteProductMapping> _plateMappings({required bool include20Kg}) => [
  _plateMapping('plate-2-5', 2.5),
  _plateMapping('plate-5', 5),
  _plateMapping('plate-10', 10),
  if (include20Kg) _plateMapping('plate-20', 20),
];

QuickQuoteProductMapping _plateMapping(String productId, double weight) =>
    _mapping(
      productId,
      section: QuickQuoteSection.weightPlate,
      roleKey: quickQuoteWeightPlateRole,
      familyKey: 'plate-family',
      plateWeightKg: weight,
    );

QuickQuoteProductMapping _mapping(
  String productId, {
  QuickQuoteMappingStatus status = QuickQuoteMappingStatus.eligible,
  required QuickQuoteSection section,
  required String roleKey,
  QuickQuoteStrengthArea? strengthArea,
  QuickQuoteLoadType? loadType,
  String? movementKey,
  String? familyKey,
  double? plateWeightKg,
  int? stationCount,
  int selectionPriority = 100,
}) => QuickQuoteProductMapping(
  productId: productId,
  status: status,
  section: section,
  roleKey: roleKey,
  strengthArea: strengthArea,
  loadType: loadType,
  movementKey: movementKey,
  familyKey: familyKey,
  plateWeightKg: plateWeightKg,
  stationCount: stationCount,
  selectionPriority: selectionPriority,
  upgradePriority: 100,
  updatedAt: DateTime.utc(2026, 10),
);
