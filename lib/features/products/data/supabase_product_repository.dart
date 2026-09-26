import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/blob.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/di/service_locator.dart';
import '../domain/bulk_update_models.dart';
import '../domain/product.dart';
import '../domain/product_code.dart';
import '../domain/product_condition.dart';
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
  String? _activeSyncOwner;
  int _syncGeneration = 0;

  SupabaseProductRepository({required this.localCache, required this.supabase});

  Future<Database> get _db async => await DatabaseService().database;

  void _checkAdmin() {
    final user = ServiceLocator().authController.currentUser;
    if (user?.isAdmin != true) {
      throw Exception('Unauthorized: Only admins can modify products.');
    }
  }

  void _checkCanCreateProduct() {
    final user = ServiceLocator().authController.currentUser;
    if (user == null || !user.isActive) {
      throw Exception(
        'Unauthorized: Only active authenticated users can create products.',
      );
    }
  }

  @override
  Future<void> init() async {
    await localCache.init();
  }

  Future<void> _syncProductsDown() async {
    if (!isConnectedToServer) return;

    final owner = _currentBusinessUserId;
    if (owner != null && _activeSync != null && _activeSyncOwner == owner) {
      return _activeSync!;
    }

    final generation = ++_syncGeneration;
    final sync = _runSync(owner, generation);
    _activeSync = sync;
    _activeSyncOwner = owner;
    return sync;
  }

  Future<void> _runSync(String? owner, int generation) async {
    try {
      await _performSyncDown(owner, generation);
    } finally {
      if (generation == _syncGeneration) {
        _activeSync = null;
        _activeSyncOwner = null;
      }
    }
  }

  Future<void> _performSyncDown(String? owner, int generation) async {
    final serverProducts = await fetchProductsFromServer();
    if (!_isCurrentSync(owner, generation)) return;

    final db = await _db;
    await db.transaction((txn) async {
      for (var row in serverProducts) {
        if (!_isCurrentSync(owner, generation)) return;
        final isDeleted = row['deleted_at'] != null;
        final serverProd = _fromSupabase(row);

        final localRecord = await _productsStore.record(serverProd.id).get(txn);

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
              normalizeProductCode(serverProd.productCode),
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
  }

  String? get _currentBusinessUserId =>
      ServiceLocator().authController.currentUser?.id;

  bool _isCurrentSync(String? owner, int generation) =>
      generation == _syncGeneration && _currentBusinessUserId == owner;

  void invalidateSession() {
    _syncGeneration++;
    _activeSync = null;
    _activeSyncOwner = null;
  }

  @override
  Future<List<Product>> getAllProducts() async {
    if (isConnectedToServer) {
      await _syncProductsDown();
    }
    return localCache.getAllProducts();
  }

  Future<void> handleRealtimeEvent(PostgresChangePayload payload) async {
    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    final db = await _db;
    await db.transaction((txn) async {
      if (eventType == PostgresChangeEvent.insert ||
          eventType == PostgresChangeEvent.update) {
        if (newRecord.isNotEmpty) {
          final serverProd = _fromSupabase(newRecord);
          if (newRecord['deleted_at'] != null) {
            await _productsStore.record(serverProd.id).delete(txn);
          } else {
            await _productsStore
                .record(serverProd.id)
                .put(txn, serverProd.toJson());
          }
        }
      } else if (eventType == PostgresChangeEvent.delete) {
        if (oldRecord.isNotEmpty && oldRecord['id'] != null) {
          await _productsStore.record(oldRecord['id'] as String).delete(txn);
        }
      }
    });

    try {
      await ServiceLocator().productMasterController.refresh();
    } catch (_) {}
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
    _checkCanCreateProduct();

    final newId = _uuid.v4();
    final now = DateTime.now();
    var updatedProduct = product.copyWith(
      id: newId,
      createdAt: now,
      updatedAt: now,
    );

    if (updatedProduct.imageBytes != null) {
      updatedProduct = updatedProduct.copyWith(imageId: _uuid.v4());
    }

    if (!(await localCache.isProductCodeUnique(updatedProduct.productCode))) {
      throw Exception('Product code must be unique');
    }

    if (!isConnectedToServer) throw Exception('Offline: Cannot save product.');
    await insertProductToServer(_toSupabase(updatedProduct));

    // 2. Save locally
    final db = await _db;
    await db.transaction((txn) async {
      if (updatedProduct.imageBytes != null) {
        await _imagesStore
            .record(updatedProduct.imageId!)
            .put(txn, Blob(updatedProduct.imageBytes!));
        await _imagesMetadataStore.record(updatedProduct.imageId!).put(txn, {
          'ownerType': 'product',
          'ownerId': newId,
        });

        // Best-effort image upload to storage
        try {
          if (isConnectedToServer) {
            final imageId = updatedProduct.imageId!;
            final uploadPath = imageId.contains('/')
                ? imageId
                : '$imageId/main.jpg';
            await supabase.client!.storage
                .from('product-images')
                .uploadBinary(uploadPath, updatedProduct.imageBytes!);
          }
        } catch (e) {
          debugPrint(
            'Storage Upload Error: Failed to upload product image. Product data was saved, but the image may be missing on the server. Details: $e',
          );
        }
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

    if (!isConnectedToServer)
      throw Exception('Offline: Cannot update product.');
    await updateProductOnServer(updatedProduct.id, _toSupabase(updatedProduct));

    // 2. Save locally
    final finalProduct = await localCache.updateProduct(updatedProduct);

    // Sync back any imageId changes
    if (finalProduct.imageId != updatedProduct.imageId) {
      await updateProductOnServer(finalProduct.id, {
        'image_id': finalProduct.imageId,
      });

      // Best-effort image upload and cleanup
      try {
        if (isConnectedToServer) {
          // Upload new image if present
          if (finalProduct.imageId != null &&
              finalProduct.imageId!.isNotEmpty &&
              finalProduct.imageBytes != null) {
            final uploadPath = finalProduct.imageId!.contains('/')
                ? finalProduct.imageId!
                : '${finalProduct.imageId}/main.jpg';
            await supabase.client!.storage
                .from('product-images')
                .uploadBinary(uploadPath, finalProduct.imageBytes!);
          }
          // Delete old image if it existed
          if (updatedProduct.imageId != null &&
              updatedProduct.imageId!.isNotEmpty) {
            final removePath = updatedProduct.imageId!.contains('/')
                ? updatedProduct.imageId!
                : '${updatedProduct.imageId}/main.jpg';
            await supabase.client!.storage.from('product-images').remove([
              removePath,
            ]);
          }
        }
      } catch (e) {
        debugPrint(
          'Storage Upload Error: Failed to upload/cleanup product image during update. Product data was updated, but the image state on the server may be inconsistent. Details: $e',
        );
      }
    }

    return finalProduct;
  }

  @override
  Future<Product> updateProductFields(
    String productId,
    ProductUpdatePatch patch,
  ) async {
    _checkAdmin();

    final existingProduct = await localCache.getProductById(productId);
    if (existingProduct == null) {
      throw StateError('Product not found: $productId');
    }
    if (patch.isEmpty) return existingProduct;

    if (!isConnectedToServer) {
      throw Exception('Offline: Cannot update product.');
    }

    final payload = _toSupabaseUpdatePatch(patch)
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final updatedRow = await updateProductFieldsOnServer(productId, payload);
    if (updatedRow == null) {
      throw StateError('Product not found: $productId');
    }

    final updatedProduct = _fromSupabase(updatedRow);
    await localCache.updateProductFields(productId, patch);
    return updatedProduct;
  }

  @override
  Future<void> toggleProductStatus(String id, bool isActive) async {
    _checkAdmin();

    if (!isConnectedToServer)
      throw Exception('Offline: Cannot toggle product status.');
    await updateProductOnServer(id, {
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

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

    if (!isConnectedToServer)
      throw Exception('Offline: Cannot delete product.');

    final product = await getProductById(id);

    await updateProductOnServer(id, {
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Best-effort image cleanup
    if (product != null &&
        product.imageId != null &&
        product.imageId!.isNotEmpty) {
      try {
        final removePath = product.imageId!.contains('/')
            ? product.imageId!
            : '${product.imageId}/main.jpg';
        await supabase.client!.storage.from('product-images').remove([
          removePath,
        ]);
      } catch (e) {
        // Ignore deletion errors
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
      'normalized_product_code': normalizeProductCode(p.productCode),
      'name': p.name,
      'category': p.category,
      'brand': p.brand,
      'condition': p.condition?.persistedValue,
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

  Map<String, dynamic> _toSupabaseUpdatePatch(ProductUpdatePatch patch) {
    return {
      if (patch.productName != null) 'name': patch.productName,
      if (patch.category != null) 'category': patch.category,
      if (patch.brand != null) 'brand': patch.brand,
      if (patch.condition != null) 'condition': patch.condition!.persistedValue,
      if (patch.sellingPrice != null) 'selling_price': patch.sellingPrice,
      if (patch.unit != null) 'unit': patch.unit,
      if (patch.minStockLevel != null) 'min_stock_level': patch.minStockLevel,
      if (patch.description != null) 'description': patch.description,
      if (patch.vatApplicable != null) 'is_vat_applicable': patch.vatApplicable,
      if (patch.isActive != null) 'is_active': patch.isActive,
    };
  }

  Product _fromSupabase(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      productCode: row['product_code'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      brand: row['brand'] as String,
      condition: ProductCondition.tryParse(row['condition']),
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

  @visibleForTesting
  Future<Map<String, dynamic>?> updateProductFieldsOnServer(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await supabase.client!
        .from('products')
        .update(data)
        .eq('id', id)
        .select()
        .maybeSingle();
  }
}
