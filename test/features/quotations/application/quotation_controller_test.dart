import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';

void main() {
  group('QuotationController', () {
    late QuotationController controller;
    const testItemId = 'li_1';

    setUp(() {
      final draft = QuotationDefaults.createEmptyDraft();
      final item = const QuotationLineItem(
        id: testItemId,
        productId: 'p1',
        productCode: 'c1',
        name: 'Item',
        brand: 'Brand',
        unitPrice: 100.0,
        quantity: 2,
      );
      controller = QuotationController(draft.copyWith(lineItems: [item]));
    });

    test('updateQuantity enforces minimum 1', () {
      controller.updateQuantity(testItemId, 0);
      expect(controller.quotation.lineItems.first.quantity, 1);

      controller.updateQuantity(testItemId, -5);
      expect(controller.quotation.lineItems.first.quantity, 1);
    });

    test('updateUnitPrice enforces non-negative', () {
      controller.updateUnitPrice(testItemId, -50.0);
      expect(controller.quotation.lineItems.first.unitPrice, 0.0);
    });

    test('updateLineDiscount clamps between 0 and 100', () {
      controller.updateLineDiscount(testItemId, -10.0);
      expect(controller.quotation.lineItems.first.discount, 0.0);

      controller.updateLineDiscount(testItemId, 150.0);
      expect(controller.quotation.lineItems.first.discount, 100.0);
    });

    test('updateCharges enforces non-negative', () {
      controller.updateCharges(discount: -100.0, vat: -5.0);
      expect(controller.quotation.charges.overallDiscount, 0.0);
      expect(controller.quotation.charges.vatPercentage, 0.0);
    });

    test('removeItem removes the correct item, including final item', () {
      controller.removeItem(testItemId);
      expect(controller.quotation.lineItems.isEmpty, isTrue);
    });
  });
}
