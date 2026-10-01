import 'dart:math' as math;

import '../../products/domain/product.dart';
import '../domain/quotation_line_item.dart';

class QuotationLineItemFactory {
  const QuotationLineItemFactory._();

  static QuotationLineItem fromProduct(
    Product product, {
    int quantity = 1,
    String? id,
  }) {
    final itemId =
        id ?? '${DateTime.now().millisecondsSinceEpoch}_${product.id}';

    return QuotationLineItem(
      id: itemId,
      productId: product.id,
      productCode: product.productCode,
      name: product.name,
      brand: product.brand,
      condition: product.condition,
      unitPrice: product.sellingPrice,
      quantity: math.max<int>(1, quantity),
      discount: 0.0,
      imageId: product.imageId,
      imageBytes: product.imageBytes,
      description: product.description,
      isCustom: false,
      isVatApplicable: product.isVatApplicable,
    );
  }
}
