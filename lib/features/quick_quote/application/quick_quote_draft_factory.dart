import '../../quotations/application/quotation_line_item_factory.dart';
import '../../quotations/domain/quotation.dart';
import '../../quotations/domain/quotation_defaults.dart';
import '../domain/quick_quote_result.dart';

class QuickQuoteDraftFactory {
  const QuickQuoteDraftFactory._();

  static bool canCreateDraft(QuickQuoteResult result) =>
      result.status != QuickQuoteBudgetStatus.insufficientBudget &&
      result.hasCompleteMinimumBalancedCoverage &&
      result.selections.isNotEmpty;

  static Quotation create({
    required QuickQuoteResult result,
    required String salespersonId,
  }) {
    if (!canCreateDraft(result)) {
      throw StateError(
        'A complete Quick Quote result is required to create a quotation draft.',
      );
    }

    final lineItems = result.selections.indexed
        .map((entry) {
          final index = entry.$1;
          final selection = entry.$2;
          return QuotationLineItemFactory.fromProduct(
            selection.candidate.product,
            quantity: selection.quantity,
            id: 'quick-quote-$index-${selection.productId}',
          );
        })
        .toList(growable: false);

    return QuotationDefaults.createEmptyDraft(
      salespersonId: salespersonId,
    ).copyWith(lineItems: lineItems);
  }
}
