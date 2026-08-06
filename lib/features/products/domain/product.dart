import 'dart:typed_data';

class Product {
  // Required
  final String id; // Internal UUID
  final String productCode; // SKU (Unique)
  final String name;
  final String category;
  final String brand;
  final double sellingPrice;
  final bool isVatApplicable;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional
  final String description;
  final String? modelNumber;
  final String unit;
  final int minStockLevel;
  final int openingStock; // For Phase 3 initialization only
  final String? notes;

  // Image handling (Blob references)
  final String? imageId; // Reference to persisted blob in images_store
  final Uint8List? imageBytes; // In-memory bytes for preview/upload

  const Product({
    required this.id,
    required this.productCode,
    required this.name,
    required this.category,
    required this.brand,
    required this.sellingPrice,
    this.isVatApplicable = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.modelNumber,
    this.unit = 'Nos',
    this.minStockLevel = 0,
    this.openingStock = 0,
    this.notes,
    this.imageId,
    this.imageBytes,
  });

  String get normalizedProductCode => productCode.trim().toUpperCase();

  Product copyWith({
    String? id,
    String? productCode,
    String? name,
    String? category,
    String? brand,
    double? sellingPrice,
    bool? isVatApplicable,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? modelNumber,
    String? unit,
    int? minStockLevel,
    int? openingStock,
    String? notes,
    String? imageId,
    Uint8List? imageBytes,
  }) {
    return Product(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      isVatApplicable: isVatApplicable ?? this.isVatApplicable,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      modelNumber: modelNumber ?? this.modelNumber,
      unit: unit ?? this.unit,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      openingStock: openingStock ?? this.openingStock,
      notes: notes ?? this.notes,
      imageId: imageId ?? this.imageId,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productCode': productCode.trim(),
      'normalizedProductCode': normalizedProductCode,
      'name': name.trim(),
      'category': category.trim(),
      'brand': brand.trim(),
      'sellingPrice': sellingPrice,
      'isVatApplicable': isVatApplicable,
      'isActive': isActive,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'description': description.trim(),
      if (modelNumber != null) 'modelNumber': modelNumber!.trim(),
      'unit': unit.trim(),
      'minStockLevel': minStockLevel,
      'openingStock': openingStock,
      if (notes != null) 'notes': notes!.trim(),
      if (imageId != null) 'imageId': imageId,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      productCode: json['productCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Uncategorized',
      brand: json['brand'] as String? ?? 'Unknown',
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      isVatApplicable: _parseBool(json['isVatApplicable'], true),
      isActive: _parseBool(json['isActive'], true),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']).toLocal()
          : DateTime.now(),
      description: json['description'] as String? ?? '',
      modelNumber: json['modelNumber'] as String?,
      unit: json['unit'] as String? ?? 'Nos',
      minStockLevel: json['minStockLevel'] as int? ?? 0,
      openingStock: json['openingStock'] as int? ?? 0,
      notes: json['notes'] as String?,
      imageId: json['imageId'] as String?,
    );
  }

  static bool _parseBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    }
    return defaultValue;
  }
}
