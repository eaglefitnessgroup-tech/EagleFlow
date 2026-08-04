import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/blob.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/di/service_locator.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'sembast_product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  final SembastProductRepository localCache;
  final SupabaseService supabase;

  final StoreRef<String, Map<String, dynamic>> _productsStore = StoreRef(
    'products',
  );
  final StoreRef<String, Blob> _imagesStore = StoreRef('images');
  final StoreRef<String, Map<String, dynamic>> _imagesMetadataStore = StoreRef(
    'images_metadata',
  );

  final Uuid _uuid = const Uuid();
  Future<void>? _activeSync;

  SupabaseProductRepository({required this.localCache, required this.supabase});

  Future<Database> get _db async => await DatabaseService().database;

  void _checkAdmin() {
    final user = ServiceLocator().authController.currentUser;
    if (user?.isAdmin != true) {
      throw Exception('Unauthorized: Only admins can modify products.');
    }
  }

  @override
  Future<void> init() async {
    await localCache.init();
    if (isConnectedToServer) {
      await _syncProductsDown();
    }
  }

  Future<void> _syncProductsDown() async {
    if (!isConnectedToServer) return;

    if (_activeSync != null) return _activeSync!;

    _activeSync = _performSyncDown().whenComplete(() {
      _activeSync = null;
    });

    return _activeSync!;
  }

  Future<void> _performSyncDown() async {
    try {
      final serverProducts = await fetchProductsFromServer();

      final db = await _db;
      await db.transaction((txn) async {
        for (var row in serverProducts) {
          final isDeleted = row['deleted_at'] != null;
          final serverProd = _fromSupabase(row);

          final localRecord = await _productsStore
              .record(serverProd.id)
              .get(txn);

          if (isDeleted) {
            if (localRecord != null) {
              await _productsStore.record(serverProd.id).delete(txn);
            }
            continue;
          }

          if (localRecord == null) {
            // Delete any local product that might have the exact same product code
            // to avoid uniqueness constraint violations.
            final finder = Finder(
              filter: Filter.equals(
                'normalizedProductCode',
                serverProd.productCode.trim().toUpperCase(),
              ),
            );
            final conflicts = await _productsStore.find(txn, finder: finder);
            for (var conflict in conflicts) {
              await _productsStore.record(conflict.key).delete(txn);
            }

            await _productsStore
                .record(serverProd.id)
                .put(txn, serverProd.toJson());
          } else {
            final localProd = Product.fromJson(localRecord);
            if (serverProd.updatedAt.isAfter(localProd.updatedAt)) {
              final merged = serverProd.copyWith(
                imageId:
                    serverProd.imageId ??
                    localProd.imageId, // Prefer server, fallback to local
              );
              await _productsStore
                  .record(serverProd.id)
                  .put(txn, merged.toJson());
            }
          }
        }
      });
    } catch (e) {
      // Background sync fail is silently ignored
    }
  }

  @override
  Future<List<Product>> getAllProducts() async {
    if (isConnectedToServer) {
      await _syncProductsDown();
    }
    return localCache.getAllProducts();
  }

  @override
  Future<Product?> getProductById(String id) async {
    return localCache.getProductById(id);
  }

  @override
  Future<Product> getProductWithImage(Product product) async {
    return localCache.getProductWithImage(product);
  }

  @override
  Future<bool> isProductCodeUnique(String code, {String? excludeId}) async {
    return localCache.isProductCodeUnique(code, excludeId: excludeId);
  }

  @override
  Future<bool> hasQuotationReferences(String productId) async {
    return localCache.hasQuotationReferences(productId);
  }

  @override
  Future<void> addProducts(List<Product> products) async {
    _checkAdmin();
    // For bulk import, remote insert is handled atomically by BulkImportService.
    // This method only handles the atomic local cache transaction.
    await localCache.addProducts(products);
  }

  @override
  Future<Product> addProduct(Product product) async {
    _checkAdmin();

    final newId = _uuid.v4();
    final now = DateTime.now();
    var updatedProduct = product.copyWith(
      id: newId,
      createdAt: now,
      updatedAt: now,
    );

    if (!(await localCache.isProductCodeUnique(updatedProduct.productCode))) {
      throw Exception('Product code must be unique');
    }

    // 1. Save to Supabase first or queue if offline/fails
    try {
      if (!isConnectedToServer) throw Exception('Offline');
      await insertProductToServer(_toSupabase(updatedProduct));
    } catch (e) {
      await ServiceLocator().syncCoordinator.queueFailedWrite(
        'products',
        _toSupabase(updatedProduct),
      );
    }

    // 2. Save locally
    final db = await _db;
    await db.transaction((txn) async {
      if (updatedProduct.imageBytes != null) {
        final newImageId = _uuid.v4();
        await _imagesStore
            .record(newImageId)
            .put(txn, Blob(updatedProduct.imageBytes!));
        await _imagesMetadataStore.record(newImageId).put(txn, {
          'ownerType': 'product',
          'ownerId': newId,
        });
        updatedProduct = updatedProduct.copyWith(imageId: newImageId);

        // Best-effort image_id update on server
        await updateProductOnServer(newId, {'image_id': newImageId});
      }

      await _productsStore.record(newId).put(txn, updatedProduct.toJson());
    });

    return updatedProduct;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    _checkAdmin();

    var updatedProduct = product.copyWith(updatedAt: DateTime.now());

    if (!(await localCache.isProductCodeUnique(
      updatedProduct.productCode,
      excludeId: updatedProduct.id,
    ))) {
      throw Exception('Product code must be unique');
    }

    // 1. Save to Supabase first or queue
    try {
      if (!isConnectedToServer) throw Exception('Offline');
      await updateProductOnServer(
        updatedProduct.id,
        _toSupabase(updatedProduct),
      );
    } catch (e) {
      await ServiceLocator().syncCoordinator.queueFailedWrite(
        'products',
        _toSupabase(updatedProduct),
      );
    }

    // 2. Save locally
    final finalProduct = await localCache.updateProduct(updatedProduct);

    // Sync back any imageId changes
    if (finalProduct.imageId != updatedProduct.imageId) {
      await updateProductOnServer(finalProduct.id, {
        'image_id': finalProduct.imageId,
      });
    }

    return finalProduct;
  }

  @override
  Future<void> toggleProductStatus(String id, bool isActive) async {
    _checkAdmin();

    try {
      if (!isConnectedToServer) throw Exception('Offline');
      await updateProductOnServer(id, {
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      final p = await getProductById(id);
      if (p != null) {
        final updated = p.copyWith(
          isActive: isActive,
          updatedAt: DateTime.now(),
        );
        await ServiceLocator().syncCoordinator.queueFailedWrite(
          'products',
          _toSupabase(updated),
        );
      }
    }

    await localCache.toggleProductStatus(id, isActive);
  }

  @override
  Future<void> deleteProduct(String id) async {
    _checkAdmin();

    final hasRefs = await localCache.hasQuotationReferences(id);
    if (hasRefs) {
      throw Exception(
        'Cannot delete product because it is referenced in existing quotations. Please deactivate it instead.',
      );
    }

    // Save to Supabase first (soft delete) or queue
    try {
      if (!isConnectedToServer) throw Exception('Offline');
      await updateProductOnServer(id, {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      final p = await getProductById(id);
      if (p != null) {
        final payload = _toSupabase(p);
        payload['deleted_at'] = DateTime.now().toUtc().toIso8601String();
        await ServiceLocator().syncCoordinator.queueFailedWrite(
          'products',
          payload,
        );
      }
    }

    // Update local cache
    await localCache.deleteProduct(id);
  }

  // ── Mappers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _toSupabase(Product p) {
    return {
      'id': p.id,
      'product_code': p.productCode,
      'normalized_product_code': p.productCode.trim().toUpperCase(),
      'name': p.name,
      'category': p.category,
      'brand': p.brand,
      'description': p.description,
      'model_number': p.modelNumber,
      'unit': p.unit,
      'selling_price': p.sellingPrice,
      'is_vat_applicable': p.isVatApplicable,
      'is_active': p.isActive,
      'min_stock_level': p.minStockLevel,
      'opening_stock': p.openingStock,
      'notes': p.notes,
      'image_id': p.imageId,
      'created_at': p.createdAt.toUtc().toIso8601String(),
      'updated_at': p.updatedAt.toUtc().toIso8601String(),
    };
  }

  Product _fromSupabase(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      productCode: row['product_code'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      brand: row['brand'] as String,
      description: row['description'] as String? ?? '',
      modelNumber: row['model_number'] as String?,
      unit: row['unit'] as String? ?? 'Nos',
      sellingPrice: (row['selling_price'] as num).toDouble(),
      isVatApplicable: row['is_vat_applicable'] as bool? ?? true,
      isActive: row['is_active'] as bool? ?? true,
      minStockLevel: row['min_stock_level'] as int? ?? 0,
      openingStock: row['opening_stock'] as int? ?? 0,
      notes: row['notes'] as String?,
      imageId: row['image_id'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }

  // ── Protected Network Methods for Testing ──────────────────────────────────

  @visibleForTesting
  bool get isConnectedToServer => supabase.isConnected;

  @visibleForTesting
  Future<List<dynamic>> fetchProductsFromServer() async {
    return await supabase.client!.from('products').select();
  }

  @visibleForTesting
  Future<void> insertProductToServer(Map<String, dynamic> data) async {
    await supabase.client!.from('products').insert(data);
  }

  @visibleForTesting
  Future<void> updateProductOnServer(
    String id,
    Map<String, dynamic> data,
  ) async {
    await supabase.client!.from('products').update(data).eq('id', id);
  }
}
