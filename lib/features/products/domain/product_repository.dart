import 'dart:async';
import '../domain/product.dart';

abstract class ProductRepository {
  /// Initialize the repository
  Future<void> init();

  /// Retrieve all products
  Future<List<Product>> getAllProducts();

  /// Retrieve a product by its ID
  Future<Product?> getProductById(String id);

  /// Retrieve a product and safely load its imageBytes from the blob store if an imageId is present
  Future<Product> getProductWithImage(Product product);

  /// Add a new product
  Future<Product> addProduct(Product product);

  /// Add multiple products atomically
  Future<void> addProducts(List<Product> products);

  /// Update an existing product
  Future<Product> updateProduct(Product product);

  /// Soft deactivate or fully activate a product
  Future<void> toggleProductStatus(String id, bool isActive);

  /// Permanently delete a product
  Future<void> deleteProduct(String id);

  /// Check if a product code is strictly unique across the database, excluding the provided ID if updating
  Future<bool> isProductCodeUnique(String code, {String? excludeId});

  /// Check if a product has active references in quotations (for safe deletion guard)
  Future<bool> hasQuotationReferences(String productId);
}
