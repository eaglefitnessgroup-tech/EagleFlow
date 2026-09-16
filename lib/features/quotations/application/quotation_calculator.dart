import 'dart:math' as math;
import '../domain/quotation_charges.dart';
import '../domain/quotation_line_item.dart';

class QuotationCalculator {
  QuotationCalculator._();

  static double calculateLineTotal(
    double unitPrice,
    int quantity,
    double discountPercent,
  ) {
    final lineBase = unitPrice * quantity;
    final lineDiscountAmount = lineBase * (discountPercent / 100.0);
    return lineBase - lineDiscountAmount;
  }

  static double calculateSubtotal(List<QuotationLineItem> items) {
    return items.fold(
      0.0,
      (sum, item) =>
          sum +
          calculateLineTotal(item.unitPrice, item.quantity, item.discount),
    );
  }

  static double calculateVAT(
    List<QuotationLineItem> items,
    QuotationCharges charges,
  ) {
    final taxableSubtotal = calculateSubtotal(
      items.where((item) => item.isVatApplicable).toList(),
    );
    final exemptSubtotal = calculateSubtotal(
      items.where((item) => !item.isVatApplicable).toList(),
    );
    final merchandiseSubtotal = taxableSubtotal + exemptSubtotal;
    final taxableDiscountShare = merchandiseSubtotal > 0
        ? charges.overallDiscount * (taxableSubtotal / merchandiseSubtotal)
        : 0.0;
    final adjustedTaxableSubtotal =
        taxableSubtotal +
        charges.deliveryCharges +
        charges.installationCharges +
        charges.otherCharges -
        taxableDiscountShare;

    final taxableAmount = math.max(adjustedTaxableSubtotal, 0.0);
    return taxableAmount * (charges.vatPercentage / 100.0);
  }

  static double calculateGrandTotal(
    List<QuotationLineItem> items,
    QuotationCharges charges,
  ) {
    final subtotal = calculateSubtotal(items);
    final adjustedSubtotal =
        subtotal +
        charges.deliveryCharges +
        charges.installationCharges +
        charges.otherCharges -
        charges.overallDiscount;

    final vat = calculateVAT(items, charges);
    return math.max(adjustedSubtotal + vat, 0.0);
  }
}
