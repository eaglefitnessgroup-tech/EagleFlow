import '../../products/domain/product.dart';
import 'quick_quote_product_mapping.dart';
import 'quick_quote_rules.dart';

class QuickQuoteCandidate {
  const QuickQuoteCandidate({required this.product, required this.mapping});

  final Product product;
  final QuickQuoteProductMapping mapping;

  String get productId => product.id;
  String get productCode => product.normalizedProductCode;
  double get sellingPrice => product.sellingPrice;
  String? get movementKey => mapping.movementKey;
  int? get stationCount => mapping.stationCount;
}

class QuickQuoteBundleLine {
  const QuickQuoteBundleLine({required this.candidate, required this.quantity});

  final QuickQuoteCandidate candidate;
  final int quantity;

  double get totalPrice => candidate.sellingPrice * quantity;
}

class QuickQuoteDumbbellBundle {
  QuickQuoteDumbbellBundle({
    required this.kind,
    required this.familyKey,
    required this.setCandidate,
    required this.rackCandidate,
    required this.rackQuantity,
  }) : lines = List<QuickQuoteBundleLine>.unmodifiable([
         QuickQuoteBundleLine(candidate: setCandidate, quantity: 1),
         QuickQuoteBundleLine(candidate: rackCandidate, quantity: rackQuantity),
       ]);

  final QuickQuoteDumbbellBundleKind kind;
  final String familyKey;
  final QuickQuoteCandidate setCandidate;
  final QuickQuoteCandidate rackCandidate;
  final int rackQuantity;
  final List<QuickQuoteBundleLine> lines;

  bool isCompatibleWith(QuickQuoteDumbbellBundle other) =>
      familyKey == other.familyKey;

  double get totalPrice =>
      lines.fold(0, (total, line) => total + line.totalPrice);
}

class QuickQuoteWeightPlateBundle {
  QuickQuoteWeightPlateBundle({
    required this.familyKey,
    required this.quantityEach,
    required List<QuickQuoteCandidate> plateCandidates,
  }) : plateCandidates = List<QuickQuoteCandidate>.unmodifiable(
         plateCandidates,
       ),
       lines = List<QuickQuoteBundleLine>.unmodifiable(
         plateCandidates.map(
           (candidate) => QuickQuoteBundleLine(
             candidate: candidate,
             quantity: quantityEach,
           ),
         ),
       );

  final String familyKey;
  final int quantityEach;
  final List<QuickQuoteCandidate> plateCandidates;
  final List<QuickQuoteBundleLine> lines;

  String get exclusivityKey => quickQuoteWeightPlateBundleExclusivityKey;

  double get totalPrice =>
      lines.fold(0, (total, line) => total + line.totalPrice);
}
