import '../domain/quotation.dart';

class QuotationValidator {
  QuotationValidator._();

  static bool canPreview(Quotation quotation) {
    if (quotation.lineItems.isEmpty) {
      return false;
    }
    if (quotation.customerInfo.name.trim().isEmpty) {
      return false;
    }
    return true;
  }
}
