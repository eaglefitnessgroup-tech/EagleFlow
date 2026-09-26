import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product createProduct({ProductCondition? condition}) {
    return Product(
      id: 'product-1',
      productCode: 'SKU-001',
      name: 'Test Product',
      category: 'Strength',
      brand: 'Eagle',
      sellingPrice: 100,
      createdAt: DateTime.utc(2026, 9, 26),
      updatedAt: DateTime.utc(2026, 9, 26),
      condition: condition,
    );
  }

  group('ProductCondition', () {
    test('parses all canonical persisted values', () {
      expect(ProductCondition.tryParse('new'), ProductCondition.newProduct);
      expect(ProductCondition.tryParse('used'), ProductCondition.used);
      expect(
        ProductCondition.tryParse('refurbished'),
        ProductCondition.refurbished,
      );
      expect(ProductCondition.tryParse('display'), ProductCondition.display);
    });

    test('parsing is case-insensitive and trims whitespace', () {
      expect(ProductCondition.tryParse(' NEW '), ProductCondition.newProduct);
      expect(ProductCondition.tryParse('uSeD'), ProductCondition.used);
      expect(
        ProductCondition.tryParse('\tRefurbished\n'),
        ProductCondition.refurbished,
      );
      expect(ProductCondition.tryParse(' DISPLAY '), ProductCondition.display);
    });

    test('invalid, malformed, and null values return null', () {
      expect(ProductCondition.tryParse('damaged'), isNull);
      expect(ProductCondition.tryParse(''), isNull);
      expect(ProductCondition.tryParse(42), isNull);
      expect(ProductCondition.tryParse(null), isNull);
    });

    test('exposes canonical display labels', () {
      expect(ProductCondition.newProduct.displayLabel, 'New');
      expect(ProductCondition.used.displayLabel, 'Used');
      expect(ProductCondition.refurbished.displayLabel, 'Refurbished');
      expect(ProductCondition.display.displayLabel, 'Display');
    });
  });

  group('Product condition persistence', () {
    test('serializes and deserializes the canonical condition value', () {
      final product = createProduct(condition: ProductCondition.refurbished);

      final json = product.toJson();
      final restored = Product.fromJson(json);

      expect(json['condition'], 'refurbished');
      expect(restored.condition, ProductCondition.refurbished);
    });

    test('legacy Product JSON without condition still loads with null', () {
      final legacyJson = createProduct().toJson()..remove('condition');

      final restored = Product.fromJson(legacyJson);

      expect(restored.condition, isNull);
    });

    test('null condition remains null through serialization', () {
      final product = createProduct();

      final json = product.toJson();
      final restored = Product.fromJson(json);

      expect(json.containsKey('condition'), isFalse);
      expect(restored.condition, isNull);
    });

    test('copyWith preserves or changes condition', () {
      final product = createProduct(condition: ProductCondition.used);

      expect(
        product.copyWith(name: 'Renamed').condition,
        ProductCondition.used,
      );
      expect(
        product.copyWith(condition: ProductCondition.display).condition,
        ProductCondition.display,
      );
    });
  });
}
