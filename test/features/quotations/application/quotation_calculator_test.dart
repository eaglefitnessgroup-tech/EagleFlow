import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/application/quotation_calculator.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';

void main() {
  group('QuotationCalculator', () {
    test('calculates line total with percentage discount', () {
      final total = QuotationCalculator.calculateLineTotal(
        100.0,
        2,
        10.0,
      ); // 10% discount on 200
      expect(total, 180.0);
    });

    test('calculates subtotal for multiple items', () {
      final items = [
        const QuotationLineItem(
          id: '1',
          productId: 'p1',
          productCode: 'c1',
          name: 'N1',
          brand: 'B1',
          unitPrice: 50.0,
          quantity: 2,
          discount: 0.0,
        ),
        const QuotationLineItem(
          id: '2',
          productId: 'p2',
          productCode: 'c2',
          name: 'N2',
          brand: 'B2',
          unitPrice: 200.0,
          quantity: 1,
          discount: 25.0, // 25% of 200 = 50 discount => 150
        ),
      ];
      final subtotal = QuotationCalculator.calculateSubtotal(items);
      expect(subtotal, 250.0);
    });

    test('VAT calculation order and negative subtotal clamping', () {
      // If overall discount is very high, adjusted subtotal could go negative before VAT.
      // Math.max(adjustedSubtotal, 0) should clamp it.
      const charges = QuotationCharges(
        overallDiscount: 1000.0, // excessive discount
        vatPercentage: 5.0,
      );
      final vat = QuotationCalculator.calculateVAT(500.0, charges);
      expect(vat, 0.0);

      final grandTotal = QuotationCalculator.calculateGrandTotal(
        500.0,
        charges,
      );
      expect(grandTotal, 0.0); // Grand total shouldn't be negative
    });
  });
}
