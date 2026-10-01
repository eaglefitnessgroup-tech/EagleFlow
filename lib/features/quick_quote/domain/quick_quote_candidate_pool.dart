import 'quick_quote_candidate.dart';
import 'quick_quote_generation_issue.dart';
import 'quick_quote_product_mapping.dart';
import 'quick_quote_rules.dart';

class QuickQuoteStrengthPoolKey {
  const QuickQuoteStrengthPoolKey({required this.area, required this.loadType});

  final QuickQuoteStrengthArea area;
  final QuickQuoteLoadType loadType;

  @override
  bool operator ==(Object other) =>
      other is QuickQuoteStrengthPoolKey &&
      area == other.area &&
      loadType == other.loadType;

  @override
  int get hashCode => Object.hash(area, loadType);
}

class QuickQuoteStrengthCandidatePool {
  QuickQuoteStrengthCandidatePool({
    required this.key,
    required List<QuickQuoteCandidate> candidates,
    required Map<String, List<QuickQuoteCandidate>> movementGroups,
  }) : candidates = List<QuickQuoteCandidate>.unmodifiable(candidates),
       movementGroups = Map<String, List<QuickQuoteCandidate>>.unmodifiable({
         for (final entry in movementGroups.entries)
           entry.key: List<QuickQuoteCandidate>.unmodifiable(entry.value),
       });

  final QuickQuoteStrengthPoolKey key;
  final List<QuickQuoteCandidate> candidates;
  final Map<String, List<QuickQuoteCandidate>> movementGroups;
}

class QuickQuoteExclusiveCandidateGroup {
  QuickQuoteExclusiveCandidateGroup({
    required this.key,
    required List<QuickQuoteCandidate> candidates,
  }) : candidates = List<QuickQuoteCandidate>.unmodifiable(candidates);

  final String key;
  final List<QuickQuoteCandidate> candidates;
}

class QuickQuoteCandidatePool {
  QuickQuoteCandidatePool({
    required Map<QuickQuoteCardioRole, List<QuickQuoteCandidate>>
    cardioCandidates,
    required Map<QuickQuoteStrengthPoolKey, QuickQuoteStrengthCandidatePool>
    strengthCandidates,
    required Map<QuickQuoteMultifunctionRole, List<QuickQuoteCandidate>>
    multifunctionCandidates,
    required this.multiStationExclusivityGroup,
    required List<QuickQuoteDumbbellBundle> dumbbellFullSetBundles,
    required List<QuickQuoteDumbbellBundle> dumbbellHalfSetBundles,
    required List<QuickQuoteWeightPlateBundle> weightPlateBundles,
    required List<QuickQuoteGenerationIssue> issues,
  }) : cardioCandidates =
           Map<QuickQuoteCardioRole, List<QuickQuoteCandidate>>.unmodifiable({
             for (final entry in cardioCandidates.entries)
               entry.key: List<QuickQuoteCandidate>.unmodifiable(entry.value),
           }),
       strengthCandidates =
           Map<
             QuickQuoteStrengthPoolKey,
             QuickQuoteStrengthCandidatePool
           >.unmodifiable(strengthCandidates),
       multifunctionCandidates =
           Map<
             QuickQuoteMultifunctionRole,
             List<QuickQuoteCandidate>
           >.unmodifiable({
             for (final entry in multifunctionCandidates.entries)
               entry.key: List<QuickQuoteCandidate>.unmodifiable(entry.value),
           }),
       dumbbellFullSetBundles = List<QuickQuoteDumbbellBundle>.unmodifiable(
         dumbbellFullSetBundles,
       ),
       dumbbellHalfSetBundles = List<QuickQuoteDumbbellBundle>.unmodifiable(
         dumbbellHalfSetBundles,
       ),
       weightPlateBundles = List<QuickQuoteWeightPlateBundle>.unmodifiable(
         weightPlateBundles,
       ),
       issues = List<QuickQuoteGenerationIssue>.unmodifiable(issues);

  final Map<QuickQuoteCardioRole, List<QuickQuoteCandidate>> cardioCandidates;
  final Map<QuickQuoteStrengthPoolKey, QuickQuoteStrengthCandidatePool>
  strengthCandidates;
  final Map<QuickQuoteMultifunctionRole, List<QuickQuoteCandidate>>
  multifunctionCandidates;
  final QuickQuoteExclusiveCandidateGroup multiStationExclusivityGroup;
  final List<QuickQuoteDumbbellBundle> dumbbellFullSetBundles;
  final List<QuickQuoteDumbbellBundle> dumbbellHalfSetBundles;
  final List<QuickQuoteWeightPlateBundle> weightPlateBundles;
  final List<QuickQuoteGenerationIssue> issues;

  QuickQuoteStrengthCandidatePool strengthPool(
    QuickQuoteStrengthArea area,
    QuickQuoteLoadType loadType,
  ) =>
      strengthCandidates[QuickQuoteStrengthPoolKey(
        area: area,
        loadType: loadType,
      )]!;
}
