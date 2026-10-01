import 'quick_quote_candidate.dart';
import 'quick_quote_product_mapping.dart';
import 'quick_quote_rules.dart';

enum QuickQuoteSelectionKind {
  cardio,
  strength,
  smithMachine,
  functionalTrainer,
  multiStation,
  dumbbellFullSet,
  dumbbellHalfSet,
  dumbbellRack,
  weightPlate,
  additionalStrength,
}

class QuickQuoteSelection {
  const QuickQuoteSelection({
    required this.candidate,
    required this.quantity,
    required this.kind,
    this.cardioRole,
    this.strengthArea,
    this.loadType,
    this.multifunctionRole,
    this.plateWeightKg,
  });

  final QuickQuoteCandidate candidate;
  final int quantity;
  final QuickQuoteSelectionKind kind;
  final QuickQuoteCardioRole? cardioRole;
  final QuickQuoteStrengthArea? strengthArea;
  final QuickQuoteLoadType? loadType;
  final QuickQuoteMultifunctionRole? multifunctionRole;
  final double? plateWeightKg;

  String get productId => candidate.productId;
  double get lineSubtotal => candidate.sellingPrice * quantity;

  QuickQuoteSelection copyWith({int? quantity}) => QuickQuoteSelection(
    candidate: candidate,
    quantity: quantity ?? this.quantity,
    kind: kind,
    cardioRole: cardioRole,
    strengthArea: strengthArea,
    loadType: loadType,
    multifunctionRole: multifunctionRole,
    plateWeightKg: plateWeightKg,
  );
}
