class QuotationLineItem {
  final String id;
  final String productId;
  final String productCode;
  final String name;
  final String brand;
  final double unitPrice;
  final int quantity;
  final double discount;
  final String? imagePath;

  const QuotationLineItem({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.name,
    required this.brand,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
    this.imagePath,
  });

  QuotationLineItem copyWith({
    String? id,
    String? productId,
    String? productCode,
    String? name,
    String? brand,
    double? unitPrice,
    int? quantity,
    double? discount,
    String? imagePath,
  }) {
    return QuotationLineItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
