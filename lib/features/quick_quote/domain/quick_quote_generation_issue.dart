import 'quick_quote_product_mapping.dart';
import 'quick_quote_rules.dart';

enum QuickQuoteGenerationIssueType {
  missingCardioRole,
  missingStrengthPinCandidate,
  missingStrengthPlateCandidate,
  missingDumbbellFullBundle,
  missingDumbbellRackCompatibility,
  missingCompletePlateFamily,
  unavailableMultifunctionRole,
}

class QuickQuoteGenerationIssue {
  const QuickQuoteGenerationIssue({
    required this.type,
    required this.message,
    this.cardioRole,
    this.strengthArea,
    this.loadType,
    this.multifunctionRole,
    this.familyKey,
  });

  final QuickQuoteGenerationIssueType type;
  final String message;
  final QuickQuoteCardioRole? cardioRole;
  final QuickQuoteStrengthArea? strengthArea;
  final QuickQuoteLoadType? loadType;
  final QuickQuoteMultifunctionRole? multifunctionRole;
  final String? familyKey;
}
