import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/products/domain/product.dart';

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

    group('Product Integration', () {
      final p1 = const Product(
        id: 'p_1',
        name: 'Product 1',
        brand: 'Brand A',
        productCode: 'c_1',
        category: 'cat',
        sellingPrice: 100.0,
        stockQuantity: 10,
        description: 'desc 1',
      );

      final p2 = const Product(
        id: 'p_2',
        name: 'Product 2',
        brand: 'Brand B',
        productCode: 'c_2',
        category: 'cat',
        sellingPrice: 200.0,
        stockQuantity: 5,
        description: 'desc 2',
      );

      test('addProduct adds new line item with correct mapping', () {
        int notifies = 0;
        controller.addListener(() => notifies++);

        controller.addProduct(p1);

        expect(notifies, 1);
        expect(controller.quotation.lineItems.length, 2); // 1 initial + 1 new
        final added = controller.quotation.lineItems.last;

        expect(added.productId, p1.id);
        expect(added.productCode, p1.productCode);
        expect(added.name, p1.name);
        expect(added.brand, p1.brand);
        expect(added.unitPrice, p1.sellingPrice);
        expect(added.quantity, 1);
        expect(added.discount, 0.0);
        expect(added.description, p1.description);
        expect(added.isCustom, false);
      });

      test('addProduct with zero or negative quantity normalizes to 1', () {
        controller.addProduct(p1, quantity: 0);
        expect(controller.quotation.lineItems.last.quantity, 1);

        controller.addProduct(p2, quantity: -5);
        expect(controller.quotation.lineItems.last.quantity, 1);
      });

      test(
        'Adding the same product twice increments quantity and preserves edits',
        () {
          controller.addProduct(p1, quantity: 2);

          // Edit price and discount
          final addedId = controller.quotation.lineItems.last.id;
          controller.updateUnitPrice(addedId, 150.0);
          controller.updateLineDiscount(addedId, 15.0);

          // Add same product again
          controller.addProduct(p1, quantity: 3);

          final items = controller.quotation.lineItems;
          expect(items.length, 2); // Still 2 (1 initial + 1 from p1)

          final updated = items.last;
          expect(updated.productId, p1.id);
          expect(updated.quantity, 5); // 2 + 3
          expect(updated.unitPrice, 150.0); // Preserved edit
          expect(updated.discount, 15.0); // Preserved edit
        },
      );

      test('addProducts adds multiple products in catalogue order', () {
        controller.addProducts([p1, p2]);

        final items = controller.quotation.lineItems;
        expect(items.length, 3);
        expect(items[1].productId, p1.id);
        expect(items[2].productId, p2.id);
      });

      test('addProducts empty list leaves quotation unchanged', () {
        int notifies = 0;
        controller.addListener(() => notifies++);

        controller.addProducts([]);

        expect(notifies, 0);
        expect(controller.quotation.lineItems.length, 1);
      });

      test('addProducts combines duplicates within the same batch safely', () {
        controller.addProducts([p1, p2, p1]); // p1 appears twice

        final items = controller.quotation.lineItems;
        expect(items.length, 3); // initial, p1, p2

        final p1Item = items.firstWhere((i) => i.productId == p1.id);
        expect(p1Item.quantity, 2); // combined 1 + 1

        final p2Item = items.firstWhere((i) => i.productId == p2.id);
        expect(p2Item.quantity, 1);
      });
    });
  });
}
