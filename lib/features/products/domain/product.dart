class Product {
  final String id;
  final String name;
  final String brand;
  final String productCode;
  final String category;
  final double sellingPrice;
  final int stockQuantity;
  final String? imagePath;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.productCode,
    required this.category,
    required this.sellingPrice,
    required this.stockQuantity,
    this.imagePath,
  });
}
