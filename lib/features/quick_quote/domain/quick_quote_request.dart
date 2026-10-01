import 'quick_quote_rules.dart';

class QuickQuoteCardioSelection {
  const QuickQuoteCardioSelection({this.productId, this.brand});

  final String? productId;
  final String? brand;

  void validate() {
    if (productId != null && productId!.trim().isEmpty) {
      throw ArgumentError('Cardio productId must not be empty');
    }
    if (brand != null && brand!.trim().isEmpty) {
      throw ArgumentError('Cardio brand must not be empty');
    }
  }
}

class QuickQuoteRequest {
  QuickQuoteRequest({
    required this.targetBudget,
    required this.strengthBrand,
    this.premierPinSeriesPrefix,
    this.premierPlateSeriesPrefix,
    Map<QuickQuoteCardioRole, QuickQuoteCardioSelection> cardioSelections =
        const {},
    this.vatBudgetMode = QuickQuoteVatBudgetMode.excludingVat,
  }) : cardioSelections =
           Map<QuickQuoteCardioRole, QuickQuoteCardioSelection>.unmodifiable(
             cardioSelections,
           ) {
    validate();
  }

  final double targetBudget;
  final String strengthBrand;
  final String? premierPinSeriesPrefix;
  final String? premierPlateSeriesPrefix;
  final Map<QuickQuoteCardioRole, QuickQuoteCardioSelection> cardioSelections;
  final QuickQuoteVatBudgetMode vatBudgetMode;

  String? get normalizedPremierPinSeriesPrefix =>
      premierPinSeriesPrefix?.trim().toUpperCase();

  String? get normalizedPremierPlateSeriesPrefix =>
      premierPlateSeriesPrefix?.trim().toUpperCase();

  void validate() {
    if (!targetBudget.isFinite || targetBudget <= 0) {
      throw ArgumentError('targetBudget must be greater than zero');
    }
    if (strengthBrand.trim().isEmpty) {
      throw ArgumentError('strengthBrand must not be empty');
    }
    for (final selection in cardioSelections.values) {
      selection.validate();
    }

    if (isPremierBrand(strengthBrand)) {
      final pinPrefix = normalizedPremierPinSeriesPrefix;
      final platePrefix = normalizedPremierPlateSeriesPrefix;
      if (pinPrefix == null ||
          !approvedPremierPinSeriesPrefixes.contains(pinPrefix)) {
        throw ArgumentError(
          'Premier pin series must be one of '
          '${approvedPremierPinSeriesPrefixes.join(', ')}',
        );
      }
      if (platePrefix == null ||
          !approvedPremierPlateSeriesPrefixes.contains(platePrefix)) {
        throw ArgumentError(
          'Premier plate series must be one of '
          '${approvedPremierPlateSeriesPrefixes.join(', ')}',
        );
      }
      return;
    }

    if (premierPinSeriesPrefix != null || premierPlateSeriesPrefix != null) {
      throw ArgumentError(
        'Premier series selections only apply to the Premier brand',
      );
    }
  }
}
