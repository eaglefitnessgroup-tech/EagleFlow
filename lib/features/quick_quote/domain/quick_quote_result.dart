import 'dart:math' as math;

import 'quick_quote_generation_issue.dart';
import 'quick_quote_product_mapping.dart';
import 'quick_quote_rules.dart';
import 'quick_quote_selection.dart';

enum QuickQuoteBudgetStatus {
  insufficientBudget,
  underTarget,
  exactTarget,
  overTarget,
}

class QuickQuoteStrengthCoverage {
  QuickQuoteStrengthCoverage({
    required this.area,
    required this.pinCount,
    required this.plateCount,
    required Set<String> movementKeys,
  }) : movementKeys = Set<String>.unmodifiable(movementKeys);

  final QuickQuoteStrengthArea area;
  final int pinCount;
  final int plateCount;
  final Set<String> movementKeys;

  bool get hasCoverage => pinCount + plateCount > 0;
  bool get hasPinAndPlate => pinCount > 0 && plateCount > 0;
}

class QuickQuoteDumbbellConfiguration {
  const QuickQuoteDumbbellConfiguration({
    required this.familyKey,
    required this.hasFullSet,
    required this.hasHalfSet,
    required this.rackQuantity,
  });

  final String? familyKey;
  final bool hasFullSet;
  final bool hasHalfSet;
  final int rackQuantity;
}

class QuickQuotePlateConfiguration {
  const QuickQuotePlateConfiguration({
    required this.familyKey,
    required this.quantityEach,
  });

  final String? familyKey;
  final int? quantityEach;
}

class QuickQuoteResult {
  QuickQuoteResult({
    required List<QuickQuoteSelection> selections,
    required this.subtotal,
    required this.vat,
    required this.grandTotal,
    required this.targetBudget,
    required this.status,
    required Map<QuickQuoteStrengthArea, QuickQuoteStrengthCoverage>
    strengthCoverage,
    required List<QuickQuoteCardioRole> selectedCardioRoles,
    required List<QuickQuoteMultifunctionRole> selectedMultifunctionRoles,
    required this.dumbbellConfiguration,
    required this.plateConfiguration,
    required List<QuickQuoteGenerationIssue> warnings,
    required this.minimumBalancedGrandTotal,
    required this.hasCompleteMinimumBalancedCoverage,
  }) : selections = List<QuickQuoteSelection>.unmodifiable(selections),
       strengthCoverage =
           Map<QuickQuoteStrengthArea, QuickQuoteStrengthCoverage>.unmodifiable(
             strengthCoverage,
           ),
       selectedCardioRoles = List<QuickQuoteCardioRole>.unmodifiable(
         selectedCardioRoles,
       ),
       selectedMultifunctionRoles =
           List<QuickQuoteMultifunctionRole>.unmodifiable(
             selectedMultifunctionRoles,
           ),
       warnings = List<QuickQuoteGenerationIssue>.unmodifiable(warnings);

  final List<QuickQuoteSelection> selections;
  final double subtotal;
  final double vat;
  final double grandTotal;
  final double targetBudget;
  final QuickQuoteBudgetStatus status;
  final Map<QuickQuoteStrengthArea, QuickQuoteStrengthCoverage>
  strengthCoverage;
  final List<QuickQuoteCardioRole> selectedCardioRoles;
  final List<QuickQuoteMultifunctionRole> selectedMultifunctionRoles;
  final QuickQuoteDumbbellConfiguration dumbbellConfiguration;
  final QuickQuotePlateConfiguration plateConfiguration;
  final List<QuickQuoteGenerationIssue> warnings;
  final double minimumBalancedGrandTotal;
  final bool hasCompleteMinimumBalancedCoverage;

  double get signedDifference => grandTotal - targetBudget;
  double get absoluteDifference => signedDifference.abs();
  double get minimumBalancedShortfall =>
      math.max(minimumBalancedGrandTotal - targetBudget, 0);
}
