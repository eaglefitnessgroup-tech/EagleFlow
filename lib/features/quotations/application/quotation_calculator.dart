import '../domain/quotation_charges.dart';
import '../domain/quotation_line_item.dart';

class QuotationCalculator {
  QuotationCalculator._();

  static double calculateLineTotal(
    double unitPrice,
    int quantity,
    double discount,
  ) {
    return (unitPrice * quantity) - discount;
  }

  static double calculateSubtotal(List<QuotationLineItem> items) {
    return items.fold(
      0.0,
      (sum, item) =>
          sum +
          calculateLineTotal(item.unitPrice, item.quantity, item.discount),
    );
  }

  static double calculateVAT(double subtotal, QuotationCharges charges) {
    final taxableAmount =
        subtotal +
        charges.deliveryCharges +
        charges.installationCharges +
        charges.otherCharges -
        charges.overallDiscount;

    return taxableAmount > 0
        ? taxableAmount * (charges.vatPercentage / 100)
        : 0.0;
  }

  static double calculateGrandTotal(double subtotal, QuotationCharges charges) {
    final vat = calculateVAT(subtotal, charges);
    return subtotal +
        charges.deliveryCharges +
        charges.installationCharges +
        charges.otherCharges -
        charges.overallDiscount +
        vat;
  }
}
