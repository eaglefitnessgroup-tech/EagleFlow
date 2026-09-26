import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseJson = <String, dynamic>{
    'id': 'item-1',
    'name': 'Product',
    'brand': 'Brand',
    'unitPrice': 100,
    'quantity': 1,
  };

  test(
    'condition serializes canonically and restores all supported values',
    () {
      for (final condition in ProductCondition.values) {
        final item = QuotationLineItem.fromJson({
          ...baseJson,
          'condition': condition.persistedValue,
        });
        expect(item.condition, condition);
        expect(item.toJson()['condition'], condition.persistedValue);
      }
    },
  );

  test('legacy, null, and malformed condition values load as null', () {
    expect(QuotationLineItem.fromJson(baseJson).condition, isNull);
    expect(
      QuotationLineItem.fromJson({...baseJson, 'condition': null}).condition,
      isNull,
    );
    expect(
      QuotationLineItem.fromJson({
        ...baseJson,
        'condition': 'not-a-condition',
      }).condition,
      isNull,
    );
  });

  test('copyWith preserves or changes the condition snapshot', () {
    const item = QuotationLineItem(
      id: 'item-1',
      name: 'Product',
      brand: 'Brand',
      condition: ProductCondition.used,
      unitPrice: 100,
      quantity: 1,
    );
    expect(item.copyWith(name: 'Renamed').condition, ProductCondition.used);
    expect(
      item.copyWith(condition: ProductCondition.refurbished).condition,
      ProductCondition.refurbished,
    );
  });
}
