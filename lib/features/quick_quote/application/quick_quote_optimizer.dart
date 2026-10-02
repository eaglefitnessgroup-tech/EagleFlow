import '../../quotations/application/quotation_calculator.dart';
import '../../quotations/application/quotation_line_item_factory.dart';
import '../../quotations/domain/quotation_charges.dart';
import '../../quotations/domain/quotation_line_item.dart';
import '../domain/quick_quote_candidate.dart';
import '../domain/quick_quote_candidate_pool.dart';
import '../domain/quick_quote_product_mapping.dart';
import '../domain/quick_quote_request.dart';
import '../domain/quick_quote_result.dart';
import '../domain/quick_quote_rules.dart';
import '../domain/quick_quote_selection.dart';

class QuickQuoteOptimizer {
  const QuickQuoteOptimizer();

  static const _charges = QuotationCharges();
  static const _epsilon = 0.0000001;

  QuickQuoteResult optimize({
    required QuickQuoteRequest request,
    required QuickQuoteCandidatePool candidatePool,
  }) {
    request.validate();

    var selections = _buildMinimumBalanced(candidatePool);
    final minimumMetrics = _calculateMetrics(selections);
    final hasCompleteMinimum = _hasCompleteMinimum(selections, candidatePool);

    if (minimumMetrics.grandTotal > request.targetBudget + _epsilon) {
      return _buildResult(
        selections: selections,
        minimumMetrics: minimumMetrics,
        targetBudget: request.targetBudget,
        candidatePool: candidatePool,
        forcedStatus: QuickQuoteBudgetStatus.insufficientBudget,
        hasCompleteMinimum: hasCompleteMinimum,
      );
    }

    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _counterpartOptions(current, candidatePool),
    );
    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _multifunctionOptions(current, candidatePool),
    );
    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _plateTierOptions(
        current,
        candidatePool,
        currentTier: 8,
        upgradedTier: 12,
      ),
    );
    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _halfDumbbellOptions(current, candidatePool),
    );
    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _plateTierOptions(
        current,
        candidatePool,
        currentTier: 12,
        upgradedTier: 15,
      ),
    );
    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _largerMultiStationOptions(current, candidatePool),
    );
    selections = _applyPriority(
      selections,
      request.targetBudget,
      (current) => _additionalStrengthOptions(current, candidatePool),
    );

    return _buildResult(
      selections: selections,
      minimumMetrics: minimumMetrics,
      targetBudget: request.targetBudget,
      candidatePool: candidatePool,
      hasCompleteMinimum: hasCompleteMinimum,
    );
  }

  List<QuickQuoteSelection> _buildMinimumBalanced(
    QuickQuoteCandidatePool pool,
  ) {
    final selections = <QuickQuoteSelection>[];

    for (final role in QuickQuoteCardioRole.values) {
      final candidates = [...pool.cardioCandidates[role]!]
        ..sort(_compareCandidates);
      if (candidates.isNotEmpty) {
        selections.add(
          QuickQuoteSelection(
            candidate: candidates.first,
            quantity: 1,
            kind: QuickQuoteSelectionKind.cardio,
            cardioRole: role,
          ),
        );
      }
    }

    for (final area in QuickQuoteStrengthArea.values) {
      final candidates = <QuickQuoteCandidate>[
        ...pool.strengthPool(area, QuickQuoteLoadType.pinLoaded).candidates,
        ...pool.strengthPool(area, QuickQuoteLoadType.plateLoaded).candidates,
      ]..sort(_compareCandidates);
      if (candidates.isNotEmpty) {
        final candidate = candidates.first;
        selections.add(
          QuickQuoteSelection(
            candidate: candidate,
            quantity: 1,
            kind: QuickQuoteSelectionKind.strength,
            strengthArea: area,
            loadType: candidate.mapping.loadType,
          ),
        );
      }
    }

    final fullBundle = _bestFullDumbbellBundle(pool.dumbbellFullSetBundles);
    if (fullBundle != null) {
      selections
        ..add(
          QuickQuoteSelection(
            candidate: fullBundle.setCandidate,
            quantity: 1,
            kind: QuickQuoteSelectionKind.dumbbellFullSet,
          ),
        )
        ..add(
          QuickQuoteSelection(
            candidate: fullBundle.rackCandidate,
            quantity: 2,
            kind: QuickQuoteSelectionKind.dumbbellRack,
          ),
        );
    }

    final basePlateBundle = _bestPlateBundle(
      pool.weightPlateBundles.where((bundle) => bundle.quantityEach == 8),
    );
    if (basePlateBundle != null) {
      selections.addAll(_plateSelections(basePlateBundle));
    }

    return selections;
  }

  List<QuickQuoteSelection> _applyPriority(
    List<QuickQuoteSelection> startingSelections,
    double target,
    List<_UpgradeOption> Function(List<QuickQuoteSelection>) buildOptions,
  ) {
    var current = List<QuickQuoteSelection>.of(startingSelections);
    while (true) {
      final currentMetrics = _calculateMetrics(current);
      final options = buildOptions(current);
      if (options.isEmpty) return current;

      final evaluated =
          options
              .map(
                (option) => _EvaluatedUpgrade(
                  option: option,
                  metrics: _calculateMetrics(option.selections),
                ),
              )
              .toList()
            ..sort((left, right) => _compareUpgrades(left, right, target));

      final best = evaluated.first;
      if (!_isBetterTotal(
        currentMetrics.grandTotal,
        best.metrics.grandTotal,
        target,
      )) {
        return current;
      }
      current = List<QuickQuoteSelection>.of(best.option.selections);
    }
  }

  List<_UpgradeOption> _counterpartOptions(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool,
  ) {
    final options = <_UpgradeOption>[];
    final selectedIds = selections
        .map((selection) => selection.productId)
        .toSet();
    final allSelectedMovements = selections
        .map((selection) => selection.candidate.movementKey)
        .whereType<String>()
        .toSet();

    for (final area in QuickQuoteStrengthArea.values) {
      final areaSelections = selections
          .where(
            (selection) =>
                selection.kind == QuickQuoteSelectionKind.strength &&
                selection.strengthArea == area,
          )
          .toList();
      if (areaSelections.isEmpty) continue;

      final selectedLoads = areaSelections
          .map((selection) => selection.loadType)
          .whereType<QuickQuoteLoadType>()
          .toSet();
      if (selectedLoads.length != 1) continue;
      final missingLoad = selectedLoads.single == QuickQuoteLoadType.pinLoaded
          ? QuickQuoteLoadType.plateLoaded
          : QuickQuoteLoadType.pinLoaded;
      final available =
          pool
              .strengthPool(area, missingLoad)
              .candidates
              .where((candidate) => !selectedIds.contains(candidate.productId))
              .toList()
            ..sort(_compareCandidates);
      if (available.isEmpty) continue;

      final differentMovements = available
          .where(
            (candidate) =>
                candidate.movementKey != null &&
                !allSelectedMovements.contains(candidate.movementKey),
          )
          .toList();
      final ranked = differentMovements.isNotEmpty
          ? differentMovements
          : available;
      for (final candidate in ranked) {
        options.add(
          _optionAdding(
            selections,
            QuickQuoteSelection(
              candidate: candidate,
              quantity: 1,
              kind: QuickQuoteSelectionKind.strength,
              strengthArea: area,
              loadType: missingLoad,
            ),
            candidate: candidate,
          ),
        );
      }
    }
    return options;
  }

  List<_UpgradeOption> _multifunctionOptions(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool,
  ) {
    final options = <_UpgradeOption>[];
    for (final role in QuickQuoteMultifunctionRole.values) {
      final alreadySelected = selections.any(
        (selection) => selection.multifunctionRole == role,
      );
      if (alreadySelected) continue;

      final candidates = [...pool.multifunctionCandidates[role]!]
        ..sort(_compareCandidates);
      for (final candidate in candidates) {
        options.add(
          _optionAdding(
            selections,
            QuickQuoteSelection(
              candidate: candidate,
              quantity: 1,
              kind: _selectionKindForMultifunction(role),
              multifunctionRole: role,
            ),
            candidate: candidate,
          ),
        );
      }
    }
    return options;
  }

  List<_UpgradeOption> _plateTierOptions(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool, {
    required int currentTier,
    required int upgradedTier,
  }) {
    final currentPlates = selections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.weightPlate,
        )
        .toList();
    if (currentPlates.length != 4 ||
        currentPlates.any((selection) => selection.quantity != currentTier)) {
      return const [];
    }

    final familyKey = currentPlates.first.candidate.mapping.familyKey;
    final currentProductIds = currentPlates
        .map((selection) => selection.productId)
        .toSet();
    final options = <_UpgradeOption>[];
    for (final bundle in pool.weightPlateBundles) {
      final bundleProductIds = bundle.plateCandidates
          .map((candidate) => candidate.productId)
          .toSet();
      if (bundle.familyKey != familyKey ||
          bundle.quantityEach != upgradedTier ||
          bundleProductIds.length != currentProductIds.length ||
          !bundleProductIds.containsAll(currentProductIds)) {
        continue;
      }
      final upgraded =
          selections
              .where(
                (selection) =>
                    selection.kind != QuickQuoteSelectionKind.weightPlate,
              )
              .toList()
            ..addAll(_plateSelections(bundle));
      options.add(
        _UpgradeOption(
          selections: upgraded,
          rankSelectionPriority: bundle.plateCandidates
              .map((candidate) => candidate.mapping.selectionPriority)
              .reduce((left, right) => left + right),
          rankPrice: bundle.totalPrice,
          rankCode: bundle.plateCandidates
              .map((candidate) => candidate.productCode)
              .join('|'),
          rankId: bundle.plateCandidates
              .map((candidate) => candidate.productId)
              .join('|'),
        ),
      );
    }
    return options;
  }

  List<_UpgradeOption> _halfDumbbellOptions(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool,
  ) {
    if (selections.any(
      (selection) => selection.kind == QuickQuoteSelectionKind.dumbbellHalfSet,
    )) {
      return const [];
    }
    final fullSets = selections.where(
      (selection) => selection.kind == QuickQuoteSelectionKind.dumbbellFullSet,
    );
    if (fullSets.isEmpty) return const [];
    final familyKey = fullSets.first.candidate.mapping.familyKey;

    final options = <_UpgradeOption>[];
    for (final bundle in pool.dumbbellHalfSetBundles) {
      if (bundle.familyKey != familyKey) continue;
      final upgraded = List<QuickQuoteSelection>.of(selections)
        ..add(
          QuickQuoteSelection(
            candidate: bundle.setCandidate,
            quantity: 1,
            kind: QuickQuoteSelectionKind.dumbbellHalfSet,
          ),
        )
        ..add(
          QuickQuoteSelection(
            candidate: bundle.rackCandidate,
            quantity: 1,
            kind: QuickQuoteSelectionKind.dumbbellRack,
          ),
        );
      options.add(
        _UpgradeOption(
          selections: upgraded,
          rankSelectionPriority: bundle.setCandidate.mapping.selectionPriority,
          rankPrice: bundle.totalPrice,
          rankCode: bundle.setCandidate.productCode,
          rankId: bundle.setCandidate.productId,
        ),
      );
    }
    return options;
  }

  List<_UpgradeOption> _largerMultiStationOptions(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool,
  ) {
    final selected = selections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.multiStation,
        )
        .toList();
    if (selected.length != 1) return const [];
    final current = selected.single;
    final currentStations = current.candidate.stationCount;
    if (currentStations == null) return const [];

    final candidates = [
      ...pool.multifunctionCandidates[QuickQuoteMultifunctionRole
          .multiStation]!,
    ]..sort(_compareCandidates);
    final options = <_UpgradeOption>[];
    for (final candidate in candidates) {
      if (candidate.productId == current.productId ||
          candidate.stationCount == null ||
          candidate.stationCount! <= currentStations) {
        continue;
      }
      final upgraded =
          selections
              .where(
                (selection) =>
                    selection.kind != QuickQuoteSelectionKind.multiStation,
              )
              .toList()
            ..add(
              QuickQuoteSelection(
                candidate: candidate,
                quantity: 1,
                kind: QuickQuoteSelectionKind.multiStation,
                multifunctionRole: QuickQuoteMultifunctionRole.multiStation,
              ),
            );
      options.add(_optionForReplacement(upgraded, candidate: candidate));
    }
    return options;
  }

  List<_UpgradeOption> _additionalStrengthOptions(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool,
  ) {
    final selectedIds = selections
        .map((selection) => selection.productId)
        .toSet();
    final selectedMovements = selections
        .where(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.strength ||
              selection.kind == QuickQuoteSelectionKind.additionalStrength,
        )
        .map((selection) => selection.candidate.movementKey)
        .whereType<String>()
        .toSet();
    final options = <_UpgradeOption>[];

    for (final area in QuickQuoteStrengthArea.values) {
      for (final loadType in QuickQuoteLoadType.values) {
        final candidates = [...pool.strengthPool(area, loadType).candidates]
          ..sort(_compareCandidates);
        for (final candidate in candidates) {
          final movementKey = candidate.movementKey;
          if (movementKey == null ||
              selectedIds.contains(candidate.productId) ||
              selectedMovements.contains(movementKey)) {
            continue;
          }
          options.add(
            _optionAdding(
              selections,
              QuickQuoteSelection(
                candidate: candidate,
                quantity: 1,
                kind: QuickQuoteSelectionKind.additionalStrength,
                strengthArea: area,
                loadType: loadType,
              ),
              candidate: candidate,
            ),
          );
        }
      }
    }
    return options;
  }

  _UpgradeOption _optionAdding(
    List<QuickQuoteSelection> selections,
    QuickQuoteSelection addition, {
    required QuickQuoteCandidate candidate,
  }) => _UpgradeOption(
    selections: [...selections, addition],
    rankSelectionPriority: candidate.mapping.selectionPriority,
    rankPrice: candidate.sellingPrice * addition.quantity,
    rankCode: candidate.productCode,
    rankId: candidate.productId,
  );

  _UpgradeOption _optionForReplacement(
    List<QuickQuoteSelection> selections, {
    required QuickQuoteCandidate candidate,
  }) => _UpgradeOption(
    selections: selections,
    rankSelectionPriority: candidate.mapping.selectionPriority,
    rankPrice: candidate.sellingPrice,
    rankCode: candidate.productCode,
    rankId: candidate.productId,
  );

  QuickQuoteDumbbellBundle? _bestFullDumbbellBundle(
    List<QuickQuoteDumbbellBundle> bundles,
  ) {
    if (bundles.isEmpty) return null;
    final sorted = [...bundles]
      ..sort((left, right) {
        var result = left.setCandidate.mapping.selectionPriority.compareTo(
          right.setCandidate.mapping.selectionPriority,
        );
        if (result != 0) return result;
        result = left.totalPrice.compareTo(right.totalPrice);
        if (result != 0) return result;
        result = left.setCandidate.productCode.compareTo(
          right.setCandidate.productCode,
        );
        if (result != 0) return result;
        result = left.setCandidate.productId.compareTo(
          right.setCandidate.productId,
        );
        if (result != 0) return result;
        return left.rackCandidate.productId.compareTo(
          right.rackCandidate.productId,
        );
      });
    return sorted.first;
  }

  QuickQuoteWeightPlateBundle? _bestPlateBundle(
    Iterable<QuickQuoteWeightPlateBundle> bundles,
  ) {
    final sorted = bundles.toList()
      ..sort((left, right) {
        final leftPriority = left.plateCandidates
            .map((candidate) => candidate.mapping.selectionPriority)
            .reduce((a, b) => a + b);
        final rightPriority = right.plateCandidates
            .map((candidate) => candidate.mapping.selectionPriority)
            .reduce((a, b) => a + b);
        var result = leftPriority.compareTo(rightPriority);
        if (result != 0) return result;
        result = left.totalPrice.compareTo(right.totalPrice);
        if (result != 0) return result;
        result = left.familyKey.compareTo(right.familyKey);
        if (result != 0) return result;
        return _plateBundleSignature(
          left,
        ).compareTo(_plateBundleSignature(right));
      });
    return sorted.isEmpty ? null : sorted.first;
  }

  List<QuickQuoteSelection> _plateSelections(
    QuickQuoteWeightPlateBundle bundle,
  ) => bundle.plateCandidates
      .map(
        (candidate) => QuickQuoteSelection(
          candidate: candidate,
          quantity: bundle.quantityEach,
          kind: QuickQuoteSelectionKind.weightPlate,
          plateWeightKg: candidate.mapping.plateWeightKg,
        ),
      )
      .toList();

  String _plateBundleSignature(QuickQuoteWeightPlateBundle bundle) =>
      bundle.plateCandidates.map((candidate) => candidate.productId).join('|');

  bool _hasCompleteMinimum(
    List<QuickQuoteSelection> selections,
    QuickQuoteCandidatePool pool,
  ) {
    final selectedCardio = selections
        .map((selection) => selection.cardioRole)
        .whereType<QuickQuoteCardioRole>()
        .toSet();
    final availableCardio = QuickQuoteCardioRole.values
        .where((role) => pool.cardioCandidates[role]!.isNotEmpty)
        .toSet();
    final strengthAreas = selections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.strength,
        )
        .map((selection) => selection.strengthArea)
        .whereType<QuickQuoteStrengthArea>()
        .toSet();
    final hasFullSet = selections.any(
      (selection) => selection.kind == QuickQuoteSelectionKind.dumbbellFullSet,
    );
    final rackQuantity = selections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.dumbbellRack,
        )
        .fold<int>(0, (sum, selection) => sum + selection.quantity);
    final plates = selections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.weightPlate,
        )
        .toList();
    final plateWeights = plates
        .map((selection) => selection.plateWeightKg)
        .whereType<double>()
        .toSet();

    return selectedCardio.containsAll(availableCardio) &&
        strengthAreas.length == QuickQuoteStrengthArea.values.length &&
        hasFullSet &&
        rackQuantity == 2 &&
        plates.length == 4 &&
        plates.every((selection) => selection.quantity == 8) &&
        plateWeights.containsAll(quickQuoteRequiredPlateWeightsKg);
  }

  _QuickQuoteMetrics _calculateMetrics(List<QuickQuoteSelection> selections) {
    final items = <QuotationLineItem>[];
    for (var index = 0; index < selections.length; index++) {
      final selection = selections[index];
      items.add(
        QuotationLineItemFactory.fromProduct(
          selection.candidate.product,
          quantity: selection.quantity,
          id: 'quick_quote_${index}_${selection.productId}',
        ),
      );
    }
    return _QuickQuoteMetrics(
      subtotal: QuotationCalculator.calculateSubtotal(items),
      vat: QuotationCalculator.calculateVAT(items, _charges),
      grandTotal: QuotationCalculator.calculateGrandTotal(items, _charges),
    );
  }

  QuickQuoteResult _buildResult({
    required List<QuickQuoteSelection> selections,
    required _QuickQuoteMetrics minimumMetrics,
    required double targetBudget,
    required QuickQuoteCandidatePool candidatePool,
    required bool hasCompleteMinimum,
    QuickQuoteBudgetStatus? forcedStatus,
  }) {
    final normalizedSelections = _normalizeAndSortSelections(selections);
    final normalizedMetrics = _calculateMetrics(normalizedSelections);
    final coverage = <QuickQuoteStrengthArea, QuickQuoteStrengthCoverage>{};
    for (final area in QuickQuoteStrengthArea.values) {
      final areaSelections = normalizedSelections.where(
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
        normalizedSelections
            .map((selection) => selection.cardioRole)
            .whereType<QuickQuoteCardioRole>()
            .toSet()
            .toList()
          ..sort((left, right) => left.index.compareTo(right.index));
    final multifunctionRoles =
        normalizedSelections
            .map((selection) => selection.multifunctionRole)
            .whereType<QuickQuoteMultifunctionRole>()
            .toSet()
            .toList()
          ..sort((left, right) => left.index.compareTo(right.index));

    final dumbbellSelections = normalizedSelections.where(
      (selection) =>
          selection.kind == QuickQuoteSelectionKind.dumbbellFullSet ||
          selection.kind == QuickQuoteSelectionKind.dumbbellHalfSet ||
          selection.kind == QuickQuoteSelectionKind.dumbbellRack,
    );
    final dumbbellFamily = dumbbellSelections
        .map((selection) => selection.candidate.mapping.familyKey)
        .whereType<String>()
        .firstOrNull;
    final plateSelections = normalizedSelections
        .where(
          (selection) => selection.kind == QuickQuoteSelectionKind.weightPlate,
        )
        .toList();

    return QuickQuoteResult(
      selections: normalizedSelections,
      subtotal: normalizedMetrics.subtotal,
      vat: normalizedMetrics.vat,
      grandTotal: normalizedMetrics.grandTotal,
      targetBudget: targetBudget,
      status:
          forcedStatus ??
          _budgetStatus(normalizedMetrics.grandTotal, targetBudget),
      strengthCoverage: coverage,
      selectedCardioRoles: cardioRoles,
      selectedMultifunctionRoles: multifunctionRoles,
      dumbbellConfiguration: QuickQuoteDumbbellConfiguration(
        familyKey: dumbbellFamily,
        hasFullSet: normalizedSelections.any(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.dumbbellFullSet,
        ),
        hasHalfSet: normalizedSelections.any(
          (selection) =>
              selection.kind == QuickQuoteSelectionKind.dumbbellHalfSet,
        ),
        rackQuantity: normalizedSelections
            .where(
              (selection) =>
                  selection.kind == QuickQuoteSelectionKind.dumbbellRack,
            )
            .fold(0, (sum, selection) => sum + selection.quantity),
      ),
      plateConfiguration: QuickQuotePlateConfiguration(
        familyKey: plateSelections
            .map((selection) => selection.candidate.mapping.familyKey)
            .whereType<String>()
            .firstOrNull,
        quantityEach: plateSelections.isEmpty
            ? null
            : plateSelections.first.quantity,
      ),
      warnings: candidatePool.issues,
      minimumBalancedGrandTotal: minimumMetrics.grandTotal,
      hasCompleteMinimumBalancedCoverage: hasCompleteMinimum,
    );
  }

  List<QuickQuoteSelection> _normalizeAndSortSelections(
    List<QuickQuoteSelection> selections,
  ) {
    final merged = <String, QuickQuoteSelection>{};
    for (final selection in selections) {
      final key = [
        selection.kind.name,
        selection.productId,
        selection.cardioRole?.name ?? '',
        selection.strengthArea?.name ?? '',
        selection.loadType?.name ?? '',
        selection.multifunctionRole?.name ?? '',
        selection.plateWeightKg?.toString() ?? '',
      ].join('|');
      final existing = merged[key];
      merged[key] = existing == null
          ? selection
          : existing.copyWith(quantity: existing.quantity + selection.quantity);
    }
    final result = merged.values.toList()..sort(_compareSelections);
    return result;
  }

  int _compareSelections(QuickQuoteSelection left, QuickQuoteSelection right) {
    var result = _selectionGroup(left).compareTo(_selectionGroup(right));
    if (result != 0) return result;

    switch (left.kind) {
      case QuickQuoteSelectionKind.cardio:
        result = left.cardioRole!.index.compareTo(right.cardioRole!.index);
      case QuickQuoteSelectionKind.strength:
        result = left.strengthArea!.index.compareTo(right.strengthArea!.index);
        if (result == 0) {
          result = left.loadType!.index.compareTo(right.loadType!.index);
        }
      case QuickQuoteSelectionKind.dumbbellFullSet:
      case QuickQuoteSelectionKind.dumbbellHalfSet:
        result = left.kind.index.compareTo(right.kind.index);
      case QuickQuoteSelectionKind.weightPlate:
        result = left.plateWeightKg!.compareTo(right.plateWeightKg!);
      case QuickQuoteSelectionKind.additionalStrength:
        result = left.strengthArea!.index.compareTo(right.strengthArea!.index);
        if (result == 0) {
          result = left.loadType!.index.compareTo(right.loadType!.index);
        }
      case QuickQuoteSelectionKind.smithMachine:
      case QuickQuoteSelectionKind.functionalTrainer:
      case QuickQuoteSelectionKind.multiStation:
      case QuickQuoteSelectionKind.dumbbellRack:
      case QuickQuoteSelectionKind.bench:
      case QuickQuoteSelectionKind.barbellSet:
      case QuickQuoteSelectionKind.barbellRack:
      case QuickQuoteSelectionKind.configuredOther:
        result = 0;
    }
    if (result != 0) return result;
    return _compareCandidates(left.candidate, right.candidate);
  }

  int _selectionGroup(QuickQuoteSelection selection) =>
      switch (selection.kind) {
        QuickQuoteSelectionKind.cardio => 0,
        QuickQuoteSelectionKind.strength => 1,
        QuickQuoteSelectionKind.smithMachine => 2,
        QuickQuoteSelectionKind.functionalTrainer => 3,
        QuickQuoteSelectionKind.multiStation => 4,
        QuickQuoteSelectionKind.dumbbellFullSet ||
        QuickQuoteSelectionKind.dumbbellHalfSet => 5,
        QuickQuoteSelectionKind.dumbbellRack => 6,
        QuickQuoteSelectionKind.weightPlate => 7,
        QuickQuoteSelectionKind.bench => 8,
        QuickQuoteSelectionKind.barbellSet => 9,
        QuickQuoteSelectionKind.barbellRack => 10,
        QuickQuoteSelectionKind.configuredOther => 11,
        QuickQuoteSelectionKind.additionalStrength => 12,
      };

  QuickQuoteSelectionKind _selectionKindForMultifunction(
    QuickQuoteMultifunctionRole role,
  ) => switch (role) {
    QuickQuoteMultifunctionRole.smithMachine =>
      QuickQuoteSelectionKind.smithMachine,
    QuickQuoteMultifunctionRole.functionalTrainer =>
      QuickQuoteSelectionKind.functionalTrainer,
    QuickQuoteMultifunctionRole.multiStation =>
      QuickQuoteSelectionKind.multiStation,
  };

  int _compareUpgrades(
    _EvaluatedUpgrade left,
    _EvaluatedUpgrade right,
    double target,
  ) {
    final leftDifference = (left.metrics.grandTotal - target).abs();
    final rightDifference = (right.metrics.grandTotal - target).abs();
    var result = leftDifference.compareTo(rightDifference);
    if (result != 0) return result;

    final leftOver = left.metrics.grandTotal > target + _epsilon;
    final rightOver = right.metrics.grandTotal > target + _epsilon;
    if (leftOver != rightOver) return leftOver ? 1 : -1;

    result = left.option.rankSelectionPriority.compareTo(
      right.option.rankSelectionPriority,
    );
    if (result != 0) return result;
    result = left.option.rankPrice.compareTo(right.option.rankPrice);
    if (result != 0) return result;
    result = left.option.rankCode.compareTo(right.option.rankCode);
    if (result != 0) return result;
    result = left.option.rankId.compareTo(right.option.rankId);
    if (result != 0) return result;
    return _selectionSignature(
      left.option.selections,
    ).compareTo(_selectionSignature(right.option.selections));
  }

  bool _isBetterTotal(double current, double proposed, double target) {
    final currentDifference = (current - target).abs();
    final proposedDifference = (proposed - target).abs();
    if (proposedDifference < currentDifference - _epsilon) return true;
    if ((proposedDifference - currentDifference).abs() <= _epsilon) {
      final currentIsOver = current > target + _epsilon;
      final proposedIsUnder = proposed < target - _epsilon;
      return currentIsOver && proposedIsUnder;
    }
    return false;
  }

  QuickQuoteBudgetStatus _budgetStatus(double total, double target) {
    final difference = total - target;
    if (difference.abs() <= _epsilon) {
      return QuickQuoteBudgetStatus.exactTarget;
    }
    return difference < 0
        ? QuickQuoteBudgetStatus.underTarget
        : QuickQuoteBudgetStatus.overTarget;
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

  String _selectionSignature(List<QuickQuoteSelection> selections) {
    final normalized = _normalizeAndSortSelections(selections);
    return normalized
        .map(
          (selection) =>
              '${selection.kind.name}:${selection.productId}:'
              '${selection.quantity}',
        )
        .join('|');
  }
}

class _UpgradeOption {
  const _UpgradeOption({
    required this.selections,
    required this.rankSelectionPriority,
    required this.rankPrice,
    required this.rankCode,
    required this.rankId,
  });

  final List<QuickQuoteSelection> selections;
  final int rankSelectionPriority;
  final double rankPrice;
  final String rankCode;
  final String rankId;
}

class _EvaluatedUpgrade {
  const _EvaluatedUpgrade({required this.option, required this.metrics});

  final _UpgradeOption option;
  final _QuickQuoteMetrics metrics;
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
