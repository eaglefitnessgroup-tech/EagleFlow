import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class ProductMasterController extends ChangeNotifier {
  final ProductRepository _repository;

  ProductMasterController(this._repository);

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get unique categories from current products for autocomplete
  List<String> get availableCategories {
    return _products
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// Get unique brands from current products for autocomplete
  List<String> get availableBrands {
    return _products
        .map((p) => p.brand.trim())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// Loads all products from the repository
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _repository.getAllProducts();
      // Apply default sorting: Newest First
      _products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = 'Failed to load products. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the product list in the background
  Future<void> refresh() async {
    try {
      final list = await _repository.getAllProducts();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _products = list;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh products');
    }
  }

  /// Add a new product
  Future<Product?> addProduct(Product product) async {
    try {
      final isUnique = await _repository.isProductCodeUnique(
        product.productCode,
      );
      if (!isUnique) {
        _error = 'Product code must be unique';
        notifyListeners();
        return null;
      }
      final newProduct = await _repository.addProduct(product);
      await refresh();
      return newProduct;
    } catch (e) {
      _error = 'Failed to add product. Please try again.';
      notifyListeners();
      return null;
    }
  }

  /// Update an existing product
  Future<bool> updateProduct(Product product) async {
    try {
      final isUnique = await _repository.isProductCodeUnique(
        product.productCode,
        excludeId: product.id,
      );
      if (!isUnique) {
        _error = 'Product code must be unique';
        notifyListeners();
        return false;
      }
      await _repository.updateProduct(product);
      await refresh();
      return true;
    } catch (e) {
      _error = 'Failed to update product. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Toggle product active status
  Future<bool> toggleProductStatus(String id, bool isActive) async {
    try {
      await _repository.toggleProductStatus(id, isActive);
      await refresh();
      return true;
    } catch (e) {
      _error = 'Failed to toggle product status. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Delete product safely
  Future<bool> deleteProduct(String id) async {
    try {
      await _repository.deleteProduct(id);
      await refresh();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Loads image for a product if necessary
  Future<Product> getProductWithImage(Product product) async {
    if (product.imageId != null && product.imageBytes == null) {
      return await _repository.getProductWithImage(product);
    }
    return product;
  }
}
