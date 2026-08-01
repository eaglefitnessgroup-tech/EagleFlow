import 'dart:typed_data';

class QuotationLineItem {
  final String id;
  final String? productId;
  final String? productCode;
  final String name;
  final String brand;
  final double unitPrice;
  final int quantity;
  final double discount;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? description;
  final bool isCustom;

  const QuotationLineItem({
    required this.id,
    this.productId,
    this.productCode,
    required this.name,
    required this.brand,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
    this.imagePath,
    this.imageBytes,
    this.description,
    this.isCustom = false,
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
    Uint8List? imageBytes,
    String? description,
    bool? isCustom,
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
      imageBytes: imageBytes ?? this.imageBytes,
      description: description ?? this.description,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
