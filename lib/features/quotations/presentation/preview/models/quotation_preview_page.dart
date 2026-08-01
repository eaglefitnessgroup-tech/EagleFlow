import '../../../domain/quotation_line_item.dart';

abstract class QuotationPreviewPage {
  const QuotationPreviewPage();
}

class QuotationProductsPageModel extends QuotationPreviewPage {
  final List<QuotationLineItem> items;
  final bool hasCover;
  final bool hasTotals;
  final bool isLastPage;

  const QuotationProductsPageModel({
    required this.items,
    this.hasCover = false,
    this.hasTotals = false,
    this.isLastPage = false,
  });
}

class QuotationInfoPageModel extends QuotationPreviewPage {
  const QuotationInfoPageModel();
}
