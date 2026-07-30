class CustomQuotationItemDraft {
  final String name;
  final String? brand;
  final String? productCode;
  final String? category;
  final String? description;
  final double sellingPrice;
  final int quantity;
  final String unit;
  final String? notes;
  final String? optionalPhotoReference;

  const CustomQuotationItemDraft({
    required this.name,
    this.brand,
    this.productCode,
    this.category,
    this.description,
    required this.sellingPrice,
    required this.quantity,
    required this.unit,
    this.notes,
    this.optionalPhotoReference,
  });
}
