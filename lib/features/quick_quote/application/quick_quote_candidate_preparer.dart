import '../../products/domain/product.dart';
import '../../products/domain/product_series.dart';
import '../domain/quick_quote_candidate.dart';
import '../domain/quick_quote_candidate_pool.dart';
import '../domain/quick_quote_generation_issue.dart';
import '../domain/quick_quote_product_mapping.dart';
import '../domain/quick_quote_request.dart';
import '../domain/quick_quote_rules.dart';

class QuickQuoteCandidatePreparer {
  QuickQuoteCandidatePool prepare({
    required QuickQuoteRequest request,
    required Iterable<Product> products,
    required Iterable<QuickQuoteProductMapping> mappings,
  }) {
    request.validate();

    final productsById = <String, Product>{};
    for (final product in products) {
      if (productsById.containsKey(product.id)) {
        throw ArgumentError('Duplicate product ID: ${product.id}');
      }
      productsById[product.id] = product;
    }

    final cardio = {
      for (final role in QuickQuoteCardioRole.values)
        role: <QuickQuoteCandidate>[],
    };
    final strength = {
      for (final area in QuickQuoteStrengthArea.values)
        for (final loadType in QuickQuoteLoadType.values)
          QuickQuoteStrengthPoolKey(area: area, loadType: loadType):
              <QuickQuoteCandidate>[],
    };
    final multifunction = {
      for (final role in QuickQuoteMultifunctionRole.values)
        role: <QuickQuoteCandidate>[],
    };
    final dumbbellsByFamily = <String, _DumbbellFamilyCandidates>{};
    final platesByFamily = <String, Map<double, List<QuickQuoteCandidate>>>{};
    final mappedProductIds = <String>{};

    for (final mapping in mappings) {
      if (!mappedProductIds.add(mapping.productId)) {
        throw ArgumentError(
          'Duplicate Quick Quote mapping product ID: ${mapping.productId}',
        );
      }
      final product = productsById[mapping.productId];
      if (product == null ||
          !product.isActive ||
          !product.sellingPrice.isFinite ||
          product.sellingPrice <= 0 ||
          !mapping.isEligible) {
        continue;
      }

      final candidate = QuickQuoteCandidate(product: product, mapping: mapping);
      switch (mapping.section) {
        case QuickQuoteSection.cardio:
          _addCardioCandidate(cardio, request, candidate);
        case QuickQuoteSection.strength:
          _addStrengthCandidate(strength, request, candidate);
        case QuickQuoteSection.multifunction:
          _addMultifunctionCandidate(multifunction, candidate);
        case QuickQuoteSection.dumbbell:
        case QuickQuoteSection.dumbbellRack:
          _addDumbbellCandidate(dumbbellsByFamily, candidate);
        case QuickQuoteSection.weightPlate:
          _addWeightPlateCandidate(platesByFamily, candidate);
        case QuickQuoteSection.bench:
        case QuickQuoteSection.freeWeight:
        case null:
          break;
      }
    }

    for (final candidates in cardio.values) {
      candidates.sort(_compareCandidates);
    }
    for (final candidates in strength.values) {
      candidates.sort(_compareCandidates);
    }
    for (final candidates in multifunction.values) {
      candidates.sort(_compareCandidates);
    }
    for (final family in dumbbellsByFamily.values) {
      family.fullSets.sort(_compareCandidates);
      family.halfSets.sort(_compareCandidates);
      family.racks.sort(_compareCandidates);
    }
    for (final weights in platesByFamily.values) {
      for (final candidates in weights.values) {
        candidates.sort(_compareCandidates);
      }
    }

    final issues = <QuickQuoteGenerationIssue>[];
    _addCardioIssues(cardio, issues);

    final strengthPools =
        <QuickQuoteStrengthPoolKey, QuickQuoteStrengthCandidatePool>{};
    for (final area in QuickQuoteStrengthArea.values) {
      for (final loadType in QuickQuoteLoadType.values) {
        final key = QuickQuoteStrengthPoolKey(area: area, loadType: loadType);
        final candidates = strength[key]!;
        strengthPools[key] = QuickQuoteStrengthCandidatePool(
          key: key,
          candidates: candidates,
          movementGroups: _groupByMovement(candidates),
        );
        if (candidates.isEmpty) {
          issues.add(
            QuickQuoteGenerationIssue(
              type: loadType == QuickQuoteLoadType.pinLoaded
                  ? QuickQuoteGenerationIssueType.missingStrengthPinCandidate
                  : QuickQuoteGenerationIssueType.missingStrengthPlateCandidate,
              strengthArea: area,
              loadType: loadType,
              message:
                  'No ${loadType.databaseValue} candidate is available '
                  'for ${area.databaseValue}.',
            ),
          );
        }
      }
    }

    final fullDumbbellBundles = <QuickQuoteDumbbellBundle>[];
    final halfDumbbellBundles = <QuickQuoteDumbbellBundle>[];
    _buildDumbbellBundles(
      dumbbellsByFamily,
      fullDumbbellBundles,
      halfDumbbellBundles,
      issues,
    );

    final weightPlateBundles = <QuickQuoteWeightPlateBundle>[];
    _buildWeightPlateBundles(platesByFamily, weightPlateBundles, issues);

    _addMultifunctionIssues(multifunction, issues);
    final multiStationCandidates =
        multifunction[QuickQuoteMultifunctionRole.multiStation]!;

    return QuickQuoteCandidatePool(
      cardioCandidates: cardio,
      strengthCandidates: strengthPools,
      multifunctionCandidates: multifunction,
      multiStationExclusivityGroup: QuickQuoteExclusiveCandidateGroup(
        key: quickQuoteMultiStationExclusivityKey,
        candidates: multiStationCandidates,
      ),
      dumbbellFullSetBundles: fullDumbbellBundles,
      dumbbellHalfSetBundles: halfDumbbellBundles,
      weightPlateBundles: weightPlateBundles,
      issues: issues,
    );
  }

  void _addCardioCandidate(
    Map<QuickQuoteCardioRole, List<QuickQuoteCandidate>> pools,
    QuickQuoteRequest request,
    QuickQuoteCandidate candidate,
  ) {
    final role = QuickQuoteCardioRole.tryParse(candidate.mapping.roleKey);
    if (role == null) return;

    final selection = request.cardioSelections[role];
    if (selection?.productId != null &&
        selection!.productId != candidate.productId) {
      return;
    }
    if (selection?.brand != null &&
        !brandsMatch(selection!.brand!, candidate.product.brand)) {
      return;
    }
    pools[role]!.add(candidate);
  }

  void _addStrengthCandidate(
    Map<QuickQuoteStrengthPoolKey, List<QuickQuoteCandidate>> pools,
    QuickQuoteRequest request,
    QuickQuoteCandidate candidate,
  ) {
    final mapping = candidate.mapping;
    final area = mapping.strengthArea;
    final loadType = mapping.loadType;
    if (area == null ||
        loadType == null ||
        mapping.movementKey == null ||
        !brandsMatch(candidate.product.brand, request.strengthBrand)) {
      return;
    }

    if (isPremierBrand(request.strengthBrand)) {
      final selectedPrefix = loadType == QuickQuoteLoadType.pinLoaded
          ? request.normalizedPremierPinSeriesPrefix
          : request.normalizedPremierPlateSeriesPrefix;
      final productPrefix = deriveProductSeriesPrefix(
        candidate.product.productCode,
      );
      if (productPrefix != selectedPrefix) return;
    }

    pools[QuickQuoteStrengthPoolKey(area: area, loadType: loadType)]!.add(
      candidate,
    );
  }

  void _addMultifunctionCandidate(
    Map<QuickQuoteMultifunctionRole, List<QuickQuoteCandidate>> pools,
    QuickQuoteCandidate candidate,
  ) {
    final role = QuickQuoteMultifunctionRole.tryParse(
      candidate.mapping.roleKey,
    );
    if (role == null) return;
    if (role == QuickQuoteMultifunctionRole.multiStation &&
        candidate.stationCount == null) {
      return;
    }
    pools[role]!.add(candidate);
  }

  void _addDumbbellCandidate(
    Map<String, _DumbbellFamilyCandidates> families,
    QuickQuoteCandidate candidate,
  ) {
    final familyKey = candidate.mapping.familyKey;
    if (familyKey == null) return;
    final family = families.putIfAbsent(
      familyKey,
      _DumbbellFamilyCandidates.new,
    );

    if (candidate.mapping.section == QuickQuoteSection.dumbbellRack &&
        candidate.mapping.roleKey == quickQuoteDumbbellRackRole) {
      family.racks.add(candidate);
    } else if (candidate.mapping.section == QuickQuoteSection.dumbbell &&
        candidate.mapping.roleKey == quickQuoteDumbbellFullSetRole) {
      family.fullSets.add(candidate);
    } else if (candidate.mapping.section == QuickQuoteSection.dumbbell &&
        candidate.mapping.roleKey == quickQuoteDumbbellHalfSetRole) {
      family.halfSets.add(candidate);
    }
  }

  void _addWeightPlateCandidate(
    Map<String, Map<double, List<QuickQuoteCandidate>>> families,
    QuickQuoteCandidate candidate,
  ) {
    final mapping = candidate.mapping;
    final familyKey = mapping.familyKey;
    final weight = mapping.plateWeightKg;
    if (mapping.roleKey != quickQuoteWeightPlateRole ||
        familyKey == null ||
        weight == null ||
        !quickQuoteRequiredPlateWeightsKg.contains(weight)) {
      return;
    }
    final weights = families.putIfAbsent(familyKey, () => {});
    weights.putIfAbsent(weight, () => []).add(candidate);
  }

  Map<String, List<QuickQuoteCandidate>> _groupByMovement(
    List<QuickQuoteCandidate> candidates,
  ) {
    final grouped = <String, List<QuickQuoteCandidate>>{};
    for (final candidate in candidates) {
      final movementKey = candidate.movementKey;
      if (movementKey == null) continue;
      grouped.putIfAbsent(movementKey, () => []).add(candidate);
    }
    final keys = grouped.keys.toList()..sort();
    return {for (final key in keys) key: grouped[key]!};
  }

  void _addCardioIssues(
    Map<QuickQuoteCardioRole, List<QuickQuoteCandidate>> pools,
    List<QuickQuoteGenerationIssue> issues,
  ) {
    for (final role in QuickQuoteCardioRole.values) {
      if (pools[role]!.isEmpty) {
        issues.add(
          QuickQuoteGenerationIssue(
            type: QuickQuoteGenerationIssueType.missingCardioRole,
            cardioRole: role,
            message: 'No candidate is available for ${role.mappingValue}.',
          ),
        );
      }
    }
  }

  void _buildDumbbellBundles(
    Map<String, _DumbbellFamilyCandidates> families,
    List<QuickQuoteDumbbellBundle> fullBundles,
    List<QuickQuoteDumbbellBundle> halfBundles,
    List<QuickQuoteGenerationIssue> issues,
  ) {
    final familyKeys = families.keys.toList()..sort();
    for (final familyKey in familyKeys) {
      final family = families[familyKey]!;
      if ((family.fullSets.isNotEmpty || family.halfSets.isNotEmpty) &&
          family.racks.isEmpty) {
        issues.add(
          QuickQuoteGenerationIssue(
            type:
                QuickQuoteGenerationIssueType.missingDumbbellRackCompatibility,
            familyKey: familyKey,
            message:
                'Dumbbell family $familyKey has no compatible rack candidate.',
          ),
        );
      }

      for (final setCandidate in family.fullSets) {
        for (final rackCandidate in family.racks) {
          fullBundles.add(
            QuickQuoteDumbbellBundle(
              kind: QuickQuoteDumbbellBundleKind.fullSet,
              familyKey: familyKey,
              setCandidate: setCandidate,
              rackCandidate: rackCandidate,
              rackQuantity: 2,
            ),
          );
        }
      }
      for (final setCandidate in family.halfSets) {
        for (final rackCandidate in family.racks) {
          halfBundles.add(
            QuickQuoteDumbbellBundle(
              kind: QuickQuoteDumbbellBundleKind.optionalHalfSet,
              familyKey: familyKey,
              setCandidate: setCandidate,
              rackCandidate: rackCandidate,
              rackQuantity: 1,
            ),
          );
        }
      }
    }

    if (fullBundles.isEmpty) {
      issues.add(
        const QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.missingDumbbellFullBundle,
          message:
              'No compatible full dumbbell set and two-rack bundle is '
              'available.',
        ),
      );
    }
  }

  void _buildWeightPlateBundles(
    Map<String, Map<double, List<QuickQuoteCandidate>>> families,
    List<QuickQuoteWeightPlateBundle> bundles,
    List<QuickQuoteGenerationIssue> issues,
  ) {
    final familyKeys = families.keys.toList()..sort();
    if (familyKeys.isEmpty) {
      issues.add(
        const QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.missingCompletePlateFamily,
          message: 'No complete weight-plate family is available.',
        ),
      );
      return;
    }

    for (final familyKey in familyKeys) {
      final weights = families[familyKey]!;
      final isComplete = quickQuoteRequiredPlateWeightsKg.every(
        (weight) => weights[weight]?.isNotEmpty ?? false,
      );
      if (!isComplete) {
        issues.add(
          QuickQuoteGenerationIssue(
            type: QuickQuoteGenerationIssueType.missingCompletePlateFamily,
            familyKey: familyKey,
            message:
                'Weight-plate family $familyKey does not include all '
                'required weights.',
          ),
        );
        continue;
      }

      final candidates2_5 = weights[2.5]!;
      final candidates5 = weights[5]!;
      final candidates10 = weights[10]!;
      final candidates20 = weights[20]!;
      for (final plate2_5 in candidates2_5) {
        for (final plate5 in candidates5) {
          for (final plate10 in candidates10) {
            for (final plate20 in candidates20) {
              final plateCandidates = [plate2_5, plate5, plate10, plate20];
              for (final tier in quickQuotePlateQuantityTiers) {
                bundles.add(
                  QuickQuoteWeightPlateBundle(
                    familyKey: familyKey,
                    quantityEach: tier,
                    plateCandidates: plateCandidates,
                  ),
                );
              }
            }
          }
        }
      }
    }
  }

  void _addMultifunctionIssues(
    Map<QuickQuoteMultifunctionRole, List<QuickQuoteCandidate>> pools,
    List<QuickQuoteGenerationIssue> issues,
  ) {
    for (final role in QuickQuoteMultifunctionRole.values) {
      if (pools[role]!.isEmpty) {
        issues.add(
          QuickQuoteGenerationIssue(
            type: QuickQuoteGenerationIssueType.unavailableMultifunctionRole,
            multifunctionRole: role,
            message: 'No candidate is available for ${role.mappingValue}.',
          ),
        );
      }
    }
  }

  int _compareCandidates(QuickQuoteCandidate left, QuickQuoteCandidate right) {
    var result = left.mapping.selectionPriority.compareTo(
      right.mapping.selectionPriority,
    );
    if (result != 0) return result;
    result = left.sellingPrice.compareTo(right.sellingPrice);
    if (result != 0) return result;
    result = left.productCode.compareTo(right.productCode);
    if (result != 0) return result;
    return left.productId.compareTo(right.productId);
  }
}

class _DumbbellFamilyCandidates {
  final List<QuickQuoteCandidate> fullSets = [];
  final List<QuickQuoteCandidate> halfSets = [];
  final List<QuickQuoteCandidate> racks = [];
}
