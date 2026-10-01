import 'dart:typed_data';

import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/application/quotation_line_item_factory.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
  final product = Product(
    id: 'product-id',
    productCode: 'APN39',
    name: 'Leg Press',
    category: 'Strength',
    brand: 'Premier',
    sellingPrice: 12345.67,
    isVatApplicable: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    description: 'Line one\nLine two',
    notes: 'Product-only note',
    condition: ProductCondition.display,
    imageId: 'image-id',
    imageBytes: imageBytes,
  );

  group('QuotationLineItemFactory.fromProduct', () {
    test('preserves the complete existing product snapshot', () {
      final item = QuotationLineItemFactory.fromProduct(
        product,
        id: 'line-item-id',
        quantity: 3,
      );

      expect(item.id, 'line-item-id');
      expect(item.productId, product.id);
      expect(item.productCode, product.productCode);
      expect(item.name, product.name);
      expect(item.brand, product.brand);
      expect(item.condition, product.condition);
      expect(item.unitPrice, product.sellingPrice);
      expect(item.quantity, 3);
      expect(item.discount, 0.0);
      expect(item.imagePath, isNull);
      expect(item.imageId, product.imageId);
      expect(item.imageBytes, same(product.imageBytes));
      expect(item.description, product.description);
      expect(item.isCustom, isFalse);
      expect(item.isVatApplicable, product.isVatApplicable);
    });

    test('keeps the previous ID pattern and quantity minimum', () {
      final item = QuotationLineItemFactory.fromProduct(product, quantity: 0);

      expect(item.id, matches(RegExp(r'^\d+_product-id$')));
      expect(item.quantity, 1);
    });

    test('QuotationController creates the same factory snapshot', () {
      final controller = QuotationController(
        QuotationDefaults.createEmptyDraft(),
      );

      controller.addProduct(product, quantity: 2);

      final actual = controller.quotation.lineItems.single;
      final expected = QuotationLineItemFactory.fromProduct(
        product,
        id: actual.id,
        quantity: 2,
      );
      expect(actual.toJson(), expected.toJson());
      expect(actual.imageBytes, same(expected.imageBytes));
    });
  });
}
