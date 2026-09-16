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

    test('calculates VAT when all items are VAT-applicable', () {
      const items = [
        QuotationLineItem(
          id: 'taxable-1',
          name: 'Taxable 1',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 2,
          discount: 10.0,
        ),
      ];
      const charges = QuotationCharges(
        deliveryCharges: 20.0,
        overallDiscount: 50.0,
        vatPercentage: 5.0,
      );

      expect(QuotationCalculator.calculateVAT(items, charges), 7.5);
      expect(QuotationCalculator.calculateGrandTotal(items, charges), 157.5);
    });

    test('calculates VAT only on taxable items in a mixed quotation', () {
      const items = [
        QuotationLineItem(
          id: 'taxable',
          name: 'Taxable',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 1,
          discount: 20.0,
        ),
        QuotationLineItem(
          id: 'exempt',
          name: 'Exempt',
          brand: 'Brand',
          unitPrice: 200.0,
          quantity: 1,
          discount: 50.0,
          isVatApplicable: false,
        ),
      ];
      const charges = QuotationCharges(vatPercentage: 5.0);

      expect(QuotationCalculator.calculateVAT(items, charges), 4.0);
      expect(QuotationCalculator.calculateGrandTotal(items, charges), 184.0);
    });

    test('allocates overall discount proportionally in a mixed quotation', () {
      const items = [
        QuotationLineItem(
          id: 'taxable',
          name: 'Taxable',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 1,
        ),
        QuotationLineItem(
          id: 'exempt',
          name: 'Exempt',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 1,
          isVatApplicable: false,
        ),
      ];
      const charges = QuotationCharges(
        overallDiscount: 20.0,
        vatPercentage: 5.0,
      );

      expect(QuotationCalculator.calculateVAT(items, charges), 4.5);
      expect(QuotationCalculator.calculateGrandTotal(items, charges), 184.5);
    });

    test('allocates all overall discount to taxable-only merchandise', () {
      const items = [
        QuotationLineItem(
          id: 'taxable',
          name: 'Taxable',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 1,
        ),
      ];
      const charges = QuotationCharges(
        overallDiscount: 20.0,
        vatPercentage: 5.0,
      );

      expect(QuotationCalculator.calculateVAT(items, charges), 4.0);
      expect(QuotationCalculator.calculateGrandTotal(items, charges), 84.0);
    });

    test('allocates no overall discount to exempt-only merchandise VAT', () {
      const items = [
        QuotationLineItem(
          id: 'exempt',
          name: 'Exempt',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 1,
          isVatApplicable: false,
        ),
      ];
      const charges = QuotationCharges(
        overallDiscount: 20.0,
        vatPercentage: 5.0,
      );

      expect(QuotationCalculator.calculateVAT(items, charges), 0.0);
      expect(QuotationCalculator.calculateGrandTotal(items, charges), 80.0);
    });

    test('handles zero merchandise subtotal without dividing by zero', () {
      const charges = QuotationCharges(
        deliveryCharges: 20.0,
        overallDiscount: 10.0,
        vatPercentage: 5.0,
      );

      expect(QuotationCalculator.calculateVAT(const [], charges), 1.0);
      expect(QuotationCalculator.calculateGrandTotal(const [], charges), 11.0);
    });

    test('calculates no VAT when all items are VAT-exempt', () {
      const items = [
        QuotationLineItem(
          id: 'exempt-1',
          name: 'Exempt 1',
          brand: 'Brand',
          unitPrice: 100.0,
          quantity: 1,
          isVatApplicable: false,
        ),
        QuotationLineItem(
          id: 'exempt-2',
          name: 'Exempt 2',
          brand: 'Brand',
          unitPrice: 200.0,
          quantity: 1,
          isVatApplicable: false,
        ),
      ];
      const charges = QuotationCharges(vatPercentage: 5.0);

      expect(QuotationCalculator.calculateVAT(items, charges), 0.0);
      expect(QuotationCalculator.calculateGrandTotal(items, charges), 300.0);
    });

    test('VAT calculation order and negative subtotal clamping', () {
      // If overall discount is very high, adjusted subtotal could go negative before VAT.
      // Math.max(adjustedSubtotal, 0) should clamp it.
      const items = [
        QuotationLineItem(
          id: '1',
          name: 'Item',
          brand: 'Brand',
          unitPrice: 500.0,
          quantity: 1,
        ),
      ];
      const charges = QuotationCharges(
        overallDiscount: 1000.0, // excessive discount
        vatPercentage: 5.0,
      );
      final vat = QuotationCalculator.calculateVAT(items, charges);
      expect(vat, 0.0);

      final grandTotal = QuotationCalculator.calculateGrandTotal(
        items,
        charges,
      );
      expect(grandTotal, 0.0); // Grand total shouldn't be negative
    });
  });
}
