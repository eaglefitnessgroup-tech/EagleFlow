import '../../products/domain/product.dart';
import '../../products/domain/product_series.dart';
import '../../quotations/application/quotation_calculator.dart';
import '../../quotations/application/quotation_line_item_factory.dart';
import '../../quotations/domain/quotation_charges.dart';
import '../../quotations/domain/quotation_line_item.dart';
import '../domain/quick_quote_active_configuration.dart';
import '../domain/quick_quote_candidate.dart';
import '../domain/quick_quote_configuration.dart';
import '../domain/quick_quote_generation_issue.dart';
import '../domain/quick_quote_product_mapping.dart';
import '../domain/quick_quote_request.dart';
import '../domain/quick_quote_result.dart';
import '../domain/quick_quote_rules.dart';
import '../domain/quick_quote_selection.dart';

class QuickQuoteConfiguredPlanningException implements Exception {
  const QuickQuoteConfiguredPlanningException(this.issue);

  final QuickQuoteGenerationIssue issue;

  @override
  String toString() => issue.message;
}

class QuickQuoteConfiguredPlanner {
  const QuickQuoteConfiguredPlanner();

  static const _charges = QuotationCharges();
  static const _epsilon = 0.0000001;

  QuickQuoteResult plan({
    required QuickQuoteRequest request,
    required QuickQuoteActiveConfiguration configuration,
    required Iterable<Product> products,
    required Iterable<QuickQuoteProductMapping> mappings,
  }) {
    request.validate();
    configuration.validate();
    final profile = configuration.resolveProfile(
      request.strengthBrand,
      request.targetBudget,
    );
    if (profile == null) {
      final available = configuration.profilesForBrand(request.strengthBrand);
      final rangeText = available.isEmpty
          ? 'No active profile is configured for ${request.strengthBrand}.'
          : 'Available configured range: '
                '${available.map((item) => item.budgetRange).join(', ')}.';
      throw QuickQuoteConfiguredPlanningException(
        QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.unsupportedBudget,
          message:
              'The target budget is not supported for ${request.strengthBrand}. $rangeText',
        ),
      );
    }

    final productsById = <String, Product>{
      for (final product in products) product.id: product,
    };
    final productsByCode = <String, List<Product>>{};
    for (final product in products) {
      productsByCode
          .putIfAbsent(product.normalizedProductCode, () => [])
          .add(product);
    }
    final mappingsByProductId = <String, QuickQuoteProductMapping>{
      for (final mapping in mappings) mapping.productId: mapping,
    };
    final roleMappings = <String, QuickQuoteConfigRoleMapping>{
      for (final mapping in configuration.roleMappings)
        _roleMappingKey(mapping.productCode, mapping.roleKey): mapping,
    };

    final indexedAllocations =
        configuration.allocations.indexed
            .where((entry) => entry.$2.profileId == profile.profileId)
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
    if (indexedAllocations.isEmpty) {
      throw QuickQuoteConfiguredPlanningException(
        QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.missingConfiguredProduct,
          message: 'The matched Quick Quote profile has no allocations.',
        ),
      );
    }

    final selections = <QuickQuoteSelection>[];
    final warnings = <QuickQuoteGenerationIssue>[];
    for (final entry in indexedAllocations) {
      final allocation = entry.$2;
      final roleMapping =
          roleMappings[_roleMappingKey(
            allocation.productCode,
            allocation.roleKey,
          )];
      final selection = _isStrength(allocation)
          ? _resolveStrength(
              request: request,
              allocation: allocation,
              configuration: configuration,
              productsById: productsById,
              productsByCode: productsByCode,
              mappingsByProductId: mappingsByProductId,
            )
          : _resolveConfiguredProduct(
              allocation: allocation,
              productsById: productsById,
              productsByCode: productsByCode,
              profile: profile,
            );
      selections.add(selection);
      if (allocation.reviewFlag ||
          roleMapping?.autoEligible.trim().toLowerCase() == 'review') {
        final detail = allocation.notes.trim().isEmpty
            ? ''
            : ' ${allocation.notes.trim()}';
        warnings.add(
          QuickQuoteGenerationIssue(
            type: QuickQuoteGenerationIssueType.reviewRequired,
            roleKey: allocation.roleKey,
            message:
                '${allocation.equipmentRole} (${allocation.productCode}) is an approved Review/Fallback row.$detail',
          ),
        );
      }
    }

    final metrics = _calculateMetrics(selections);
    final coverage = <QuickQuoteStrengthArea, QuickQuoteStrengthCoverage>{};
    for (final area in QuickQuoteStrengthArea.values) {
      final areaSelections = selections.where(
        (selection) => selection.strengthArea == area,
      );
      coverage[area] = QuickQuoteStrengthCoverage(
        area: area,
        pinCount: areaSelections
            .where(
              (selection) => selection.loadType == QuickQuoteLoadType.pinLoaded,
            )
            .length,
        plateCount: areaSelections
            .where(
              (selection) =>
                  selection.loadType == QuickQuoteLoadType.plateLoaded,
            )
            .length,
        movementKeys: areaSelections
            .map((selection) => selection.candidate.movementKey)
            .whereType<String>()
            .toSet(),
      );
    }
    final cardioRoles =
        selections
            .map((selection) => selection.cardioRole)
            .whereType<QuickQuoteCardioRole>()
            .toSet()
            .toList()
          ..sort((left, right) => left.index.compareTo(right.index));
    final multifunctionRoles =
        selections
            .map((selection) => selection.multifunctionRole)
            .whereType<QuickQuoteMultifunctionRole>()
            .toSet()
            .toList()
          ..sort((left, right) => left.index.compareTo(right.index));
    final dumbbells = selections.where(
      (selection) =>
          selection.kind == QuickQuoteSelectionKind.dumbbellFullSet ||
          selection.kind == QuickQuoteSelectionKind.dumbbellHalfSet ||
          selection.kind == QuickQuoteSelectionKind.dumbbellRack,
    );
    final plates = selections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.weightPlate,
        )
        .toList(growable: false);

    return QuickQuoteResult(
      selections: selections,
      subtotal: metrics.subtotal,
      vat: metrics.vat,
      grandTotal: metrics.grandTotal,
      targetBudget: request.targetBudget,
      status: _budgetStatus(metrics.grandTotal, request.targetBudget),
      strengthCoverage: coverage,
      selectedCardioRoles: cardioRoles,
      selectedMultifunctionRoles: multifunctionRoles,
      dumbbellConfiguration: QuickQuoteDumbbellConfiguration(
        familyKey: dumbbells
            .map((selection) => selection.candidate.mapping.familyKey)
            .whereType<String>()
            .firstOrNull,
        hasFullSet: selections.any(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.dumbbellFullSet,
        ),
        hasHalfSet: selections.any(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.dumbbellHalfSet,
        ),
        rackQuantity: selections
            .where(
              (selection) =>
                  selection.kind == QuickQuoteSelectionKind.dumbbellRack,
            )
            .fold(0, (sum, selection) => sum + selection.quantity),
      ),
      plateConfiguration: QuickQuotePlateConfiguration(
        familyKey: plates
            .map((selection) => selection.candidate.mapping.familyKey)
            .whereType<String>()
            .firstOrNull,
        quantityEach: plates.isEmpty ? null : plates.first.quantity,
      ),
      warnings: warnings,
      minimumBalancedGrandTotal: metrics.grandTotal,
      hasCompleteMinimumBalancedCoverage: true,
    );
  }

  QuickQuoteSelection _resolveStrength({
    required QuickQuoteRequest request,
    required QuickQuoteConfigAllocation allocation,
    required QuickQuoteActiveConfiguration configuration,
    required Map<String, Product> productsById,
    required Map<String, List<Product>> productsByCode,
    required Map<String, QuickQuoteProductMapping> mappingsByProductId,
  }) {
    final reference = _resolveLiveProduct(
      allocation,
      productsById,
      productsByCode,
    );
    final referenceMapping = mappingsByProductId[reference.id];
    final priority = configuration.strengthPriorities
        .where(
          (row) =>
              _token(row.brand) == _token(request.strengthBrand) &&
              (row.productId == reference.id ||
                  _code(row.productCode) == reference.normalizedProductCode),
        )
        .firstOrNull;
    final area =
        referenceMapping?.strengthArea ??
        _parseStrengthArea(priority?.strengthArea ?? allocation.equipmentRole);
    final loadType =
        referenceMapping?.loadType ?? _parseLoadType(priority?.loadType);
    final movementKey = referenceMapping?.movementKey;
    if (area == null || loadType == null || movementKey == null) {
      _throwMissingMovement(allocation, request.strengthBrand);
    }

    Product selectedProduct = reference;
    QuickQuoteProductMapping selectedMapping = referenceMapping!;
    if (isPremierBrand(request.strengthBrand)) {
      final selectedPrefix = loadType == QuickQuoteLoadType.pinLoaded
          ? request.normalizedPremierPinSeriesPrefix
          : request.normalizedPremierPlateSeriesPrefix;
      final referencePrefix = deriveProductSeriesPrefix(reference.productCode);
      if (referencePrefix != selectedPrefix) {
        final candidates = mappingsByProductId.values
            .where(
              (mapping) =>
                  mapping.isEligible &&
                  mapping.section == QuickQuoteSection.strength &&
                  mapping.strengthArea == area &&
                  mapping.loadType == loadType &&
                  mapping.movementKey == movementKey,
            )
            .map((mapping) => (mapping, productsById[mapping.productId]))
            .where(
              (entry) =>
                  entry.$2 != null &&
                  entry.$2!.isActive &&
                  entry.$2!.sellingPrice.isFinite &&
                  entry.$2!.sellingPrice > 0 &&
                  isPremierBrand(entry.$2!.brand) &&
                  deriveProductSeriesPrefix(entry.$2!.productCode) ==
                      selectedPrefix,
            )
            .toList();
        if (candidates.isEmpty) {
          _throwMissingMovement(
            allocation,
            '$selectedPrefix ${area.databaseValue}',
          );
        }
        final bestPriority = candidates
            .map((entry) => entry.$1.selectionPriority)
            .reduce((left, right) => left < right ? left : right);
        final preferred = candidates
            .where((entry) => entry.$1.selectionPriority == bestPriority)
            .toList();
        if (preferred.length != 1) {
          throw QuickQuoteConfiguredPlanningException(
            QuickQuoteGenerationIssue(
              type: QuickQuoteGenerationIssueType.ambiguousConfiguredMovement,
              roleKey: allocation.roleKey,
              strengthArea: area,
              loadType: loadType,
              message:
                  'The configured movement ${allocation.equipmentRole} has multiple $selectedPrefix candidates at selection priority $bestPriority.',
            ),
          );
        }
        selectedMapping = preferred.single.$1;
        selectedProduct = preferred.single.$2!;
      }
    }

    return QuickQuoteSelection(
      candidate: QuickQuoteCandidate(
        product: selectedProduct,
        mapping: selectedMapping,
      ),
      quantity: allocation.quantity,
      kind: QuickQuoteSelectionKind.strength,
      strengthArea: area,
      loadType: loadType,
      configurationRoleKey: allocation.roleKey,
      sectionOrder: allocation.sectionOrder,
      configurationPriority: allocation.priority,
    );
  }

  Never _throwMissingMovement(
    QuickQuoteConfigAllocation allocation,
    String selection,
  ) {
    throw QuickQuoteConfiguredPlanningException(
      QuickQuoteGenerationIssue(
        type: QuickQuoteGenerationIssueType.missingConfiguredMovement,
        roleKey: allocation.roleKey,
        message:
            'The configured movement ${allocation.equipmentRole} cannot be resolved in $selection.',
      ),
    );
  }

  QuickQuoteSelection _resolveConfiguredProduct({
    required QuickQuoteConfigAllocation allocation,
    required Map<String, Product> productsById,
    required Map<String, List<Product>> productsByCode,
    required QuickQuoteBudgetProfile profile,
  }) {
    final product = _resolveLiveProduct(
      allocation,
      productsById,
      productsByCode,
    );
    final shape = _configuredShape(allocation, profile);
    final mapping = QuickQuoteProductMapping(
      productId: product.id,
      status: QuickQuoteMappingStatus.eligible,
      section: shape.section,
      roleKey: shape.mappingRoleKey,
      strengthArea: null,
      loadType: null,
      movementKey: null,
      familyKey: shape.familyKey,
      plateWeightKg: shape.plateWeightKg,
      stationCount: shape.stationCount,
      selectionPriority: allocation.priority,
      upgradePriority: allocation.priority,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    return QuickQuoteSelection(
      candidate: QuickQuoteCandidate(product: product, mapping: mapping),
      quantity: allocation.quantity,
      kind: shape.kind,
      cardioRole: shape.cardioRole,
      multifunctionRole: shape.multifunctionRole,
      plateWeightKg: shape.plateWeightKg,
      configurationRoleKey: allocation.roleKey,
      sectionOrder: allocation.sectionOrder,
      configurationPriority: allocation.priority,
    );
  }

  Product _resolveLiveProduct(
    QuickQuoteConfigAllocation allocation,
    Map<String, Product> productsById,
    Map<String, List<Product>> productsByCode,
  ) {
    final configuredId = allocation.productId;
    Product? product;
    if (configuredId != null && configuredId.trim().isNotEmpty) {
      product = productsById[configuredId];
      if (product != null &&
          product.normalizedProductCode != _code(allocation.productCode)) {
        product = null;
      }
    } else {
      final byCode = productsByCode[_code(allocation.productCode)] ?? const [];
      if (byCode.length == 1) product = byCode.single;
    }
    if (product == null) {
      throw QuickQuoteConfiguredPlanningException(
        QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.missingConfiguredProduct,
          roleKey: allocation.roleKey,
          message:
              '${allocation.equipmentRole} (${allocation.productCode}) no longer exists in the product catalog.',
        ),
      );
    }
    if (!product.isActive) {
      throw QuickQuoteConfiguredPlanningException(
        QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.inactiveConfiguredProduct,
          roleKey: allocation.roleKey,
          message:
              '${allocation.equipmentRole} (${allocation.productCode}) is inactive.',
        ),
      );
    }
    if (!product.sellingPrice.isFinite || product.sellingPrice <= 0) {
      throw QuickQuoteConfiguredPlanningException(
        QuickQuoteGenerationIssue(
          type: QuickQuoteGenerationIssueType.invalidConfiguredPrice,
          roleKey: allocation.roleKey,
          message:
              '${allocation.equipmentRole} (${allocation.productCode}) has no valid selling price.',
        ),
      );
    }
    return product;
  }

  _ConfiguredShape _configuredShape(
    QuickQuoteConfigAllocation allocation,
    QuickQuoteBudgetProfile profile,
  ) {
    final role = allocation.roleKey.trim().toLowerCase();
    if (role.startsWith('cardio_')) {
      final mappingRole = role.substring('cardio_'.length);
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.cardio,
        section: QuickQuoteSection.cardio,
        mappingRoleKey: mappingRole,
        cardioRole: QuickQuoteCardioRole.tryParse(mappingRole),
      );
    }
    if (role == 'functional_multi_smith_machine') {
      return const _ConfiguredShape(
        kind: QuickQuoteSelectionKind.smithMachine,
        section: QuickQuoteSection.multifunction,
        mappingRoleKey: 'smith_machine',
        multifunctionRole: QuickQuoteMultifunctionRole.smithMachine,
      );
    }
    if (role == 'functional_multi_functional_trainer') {
      return const _ConfiguredShape(
        kind: QuickQuoteSelectionKind.functionalTrainer,
        section: QuickQuoteSection.multifunction,
        mappingRoleKey: 'functional_trainer',
        multifunctionRole: QuickQuoteMultifunctionRole.functionalTrainer,
      );
    }
    final stationMatch = RegExp(
      r'^functional_multi_(4|5|8)_station$',
    ).firstMatch(role);
    if (stationMatch != null) {
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.multiStation,
        section: QuickQuoteSection.multifunction,
        mappingRoleKey: 'multi_station',
        multifunctionRole: QuickQuoteMultifunctionRole.multiStation,
        stationCount: int.parse(stationMatch.group(1)!),
      );
    }
    if (role == 'free_weights_dumbbell_full_set_2_5_50kg') {
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.dumbbellFullSet,
        section: QuickQuoteSection.dumbbell,
        mappingRoleKey: quickQuoteDumbbellFullSetRole,
        familyKey: _token(profile.brand),
      );
    }
    if (role == 'free_weights_dumbbell_half_set_2_5_25kg') {
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.dumbbellHalfSet,
        section: QuickQuoteSection.dumbbell,
        mappingRoleKey: quickQuoteDumbbellHalfSetRole,
        familyKey: _token(profile.brand),
      );
    }
    if (role == 'free_weights_dumbbell_rack') {
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.dumbbellRack,
        section: QuickQuoteSection.dumbbellRack,
        mappingRoleKey: quickQuoteDumbbellRackRole,
        familyKey: _token(profile.brand),
      );
    }
    final plateMatch = RegExp(
      r'^free_weights_(tpu|pu)_weight_plate_(2_5|5|10|20)kg$',
    ).firstMatch(role);
    if (plateMatch != null) {
      final family = plateMatch.group(1)!;
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.weightPlate,
        section: QuickQuoteSection.weightPlate,
        mappingRoleKey: quickQuoteWeightPlateRole,
        familyKey: '${_token(profile.brand)}_$family',
        plateWeightKg: double.parse(
          plateMatch.group(2)!.replaceFirst('_', '.'),
        ),
      );
    }
    if (role.startsWith('benches_')) {
      return _ConfiguredShape(
        kind: QuickQuoteSelectionKind.bench,
        section: QuickQuoteSection.bench,
        mappingRoleKey: role,
      );
    }
    if (role == 'free_weights_barbell_set') {
      return const _ConfiguredShape(
        kind: QuickQuoteSelectionKind.barbellSet,
        section: QuickQuoteSection.freeWeight,
        mappingRoleKey: 'barbell_set',
      );
    }
    if (role == 'free_weights_barbell_rack') {
      return const _ConfiguredShape(
        kind: QuickQuoteSelectionKind.barbellRack,
        section: QuickQuoteSection.freeWeight,
        mappingRoleKey: 'barbell_rack',
      );
    }
    return _ConfiguredShape(
      kind: QuickQuoteSelectionKind.configuredOther,
      section: QuickQuoteSection.freeWeight,
      mappingRoleKey: role,
    );
  }

  _QuickQuoteMetrics _calculateMetrics(List<QuickQuoteSelection> selections) {
    final items = <QuotationLineItem>[
      for (final (index, selection) in selections.indexed)
        QuotationLineItemFactory.fromProduct(
          selection.candidate.product,
          quantity: selection.quantity,
          id: 'quick_quote_${index}_${selection.productId}',
        ),
    ];
    return _QuickQuoteMetrics(
      subtotal: QuotationCalculator.calculateSubtotal(items),
      vat: QuotationCalculator.calculateVAT(items, _charges),
      grandTotal: QuotationCalculator.calculateGrandTotal(items, _charges),
    );
  }

  QuickQuoteBudgetStatus _budgetStatus(double total, double target) {
    final difference = total - target;
    if (difference.abs() <= _epsilon) return QuickQuoteBudgetStatus.exactTarget;
    return difference < 0
        ? QuickQuoteBudgetStatus.underTarget
        : QuickQuoteBudgetStatus.overTarget;
  }
}

class _ConfiguredShape {
  const _ConfiguredShape({
    required this.kind,
    required this.section,
    required this.mappingRoleKey,
    this.cardioRole,
    this.multifunctionRole,
    this.familyKey,
    this.plateWeightKg,
    this.stationCount,
  });

  final QuickQuoteSelectionKind kind;
  final QuickQuoteSection section;
  final String mappingRoleKey;
  final QuickQuoteCardioRole? cardioRole;
  final QuickQuoteMultifunctionRole? multifunctionRole;
  final String? familyKey;
  final double? plateWeightKg;
  final int? stationCount;
}

class _QuickQuoteMetrics {
  const _QuickQuoteMetrics({
    required this.subtotal,
    required this.vat,
    required this.grandTotal,
  });

  final double subtotal;
  final double vat;
  final double grandTotal;
}

bool _isStrength(QuickQuoteConfigAllocation allocation) =>
    allocation.section.trim().toLowerCase() == 'strength';

QuickQuoteStrengthArea? _parseStrengthArea(String? value) =>
    switch (_token(value ?? '')) {
      'chest' => QuickQuoteStrengthArea.chest,
      'back' => QuickQuoteStrengthArea.back,
      'shoulder' => QuickQuoteStrengthArea.shoulder,
      'legs' => QuickQuoteStrengthArea.legs,
      'arms' => QuickQuoteStrengthArea.arms,
      'glutes' => QuickQuoteStrengthArea.glutes,
      'core' || 'core / abs' || 'core_abs' => QuickQuoteStrengthArea.core,
      _ => null,
    };

QuickQuoteLoadType? _parseLoadType(String? value) =>
    switch (_token(value ?? '').replaceAll(' ', '_')) {
      'pin_loaded' => QuickQuoteLoadType.pinLoaded,
      'plate_loaded' => QuickQuoteLoadType.plateLoaded,
      _ => null,
    };

String _roleMappingKey(String productCode, String roleKey) =>
    '${_code(productCode)}|${_token(roleKey)}';

String _code(String value) => value.trim().toUpperCase();
String _token(String value) => value.trim().toLowerCase();
