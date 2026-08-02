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
  final String? imageId; // Reference to persisted blob
  final String? description;
  final bool isCustom;
  final bool isVatApplicable;

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
    this.imageId,
    this.description,
    this.isCustom = false,
    this.isVatApplicable = true,
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
    String? imageId,
    String? description,
    bool? isCustom,
    bool? isVatApplicable,
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
      imageId: imageId ?? this.imageId,
      description: description ?? this.description,
      isCustom: isCustom ?? this.isCustom,
      isVatApplicable: isVatApplicable ?? this.isVatApplicable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productCode': productCode,
      'name': name,
      'brand': brand,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'discount': discount,
      'imagePath': imagePath,
      'imageId': imageId,
      'description': description,
      'isCustom': isCustom,
      'isVatApplicable': isVatApplicable,
    };
  }

  factory QuotationLineItem.fromJson(Map<String, dynamic> json) {
    return QuotationLineItem(
      id: json['id'] as String,
      productId: json['productId'] as String?,
      productCode: json['productCode'] as String?,
      name: json['name'] as String,
      brand: json['brand'] as String? ?? '',
      unitPrice: (json['unitPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      imagePath: json['imagePath'] as String?,
      imageId: json['imageId'] as String?,
      description: json['description'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
      isVatApplicable: json['isVatApplicable'] as bool? ?? true,
    );
  }
}
