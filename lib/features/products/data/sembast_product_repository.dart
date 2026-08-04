import 'dart:typed_data';
import 'package:sembast/sembast.dart';
import 'package:sembast/blob.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import '../../quotations/domain/quotation.dart';

class SembastProductRepository implements ProductRepository {
  final StoreRef<String, Map<String, dynamic>> _productsStore =
      StoreRef<String, Map<String, dynamic>>('products');
  final StoreRef<String, Blob> _imagesStore = StoreRef<String, Blob>('images');
  final StoreRef<String, Map<String, dynamic>> _imagesMetadataStore =
      StoreRef<String, Map<String, dynamic>>('images_metadata');

  // Need quotations store to check for references safely
  final StoreRef<String, Map<String, dynamic>> _quotationsStore =
      StoreRef<String, Map<String, dynamic>>('quotations');

  final StoreRef<String, bool> _metadataStore = StoreRef<String, bool>(
    'metadata_flags',
  );

  final Uuid _uuid = const Uuid();

  Future<Database> get _db async => await DatabaseService().database;

  @override
  Future<void> init() async {
    final db = await _db;
    final seeded =
        await _metadataStore.record('products_seeded').get(db) ?? false;
    if (!seeded) {
      await db.transaction((txn) async {
        // Temporarily disabled for development QA
        // // Also check if products are actually empty
        // final count = await _productsStore.count(txn);
        // if (count == 0) {
        //   for (var p in sampleProducts) {
        //     final newId = _uuid.v4();
        //     final now = DateTime.now();
        //     final productToSave = p.copyWith(
        //       id: newId,
        //       createdAt: now,
        //       updatedAt: now,
        //     );
        //     await _productsStore.record(newId).put(txn, productToSave.toJson());
        //   }
        // }
        await _metadataStore.record('products_seeded').put(txn, true);
      });
    }
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final db = await _db;
    final records = await _productsStore.find(db);
    return records.map((r) => Product.fromJson(r.value)).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final db = await _db;
    final record = await _productsStore.record(id).get(db);
    if (record != null) {
      return Product.fromJson(record);
    }
    return null;
  }

  @override
  Future<Product> getProductWithImage(Product product) async {
    if (product.imageId != null && product.imageBytes == null) {
      final db = await _db;
      final blob = await _imagesStore.record(product.imageId!).get(db);
      if (blob != null) {
        return product.copyWith(imageBytes: blob.bytes);
      }
    }
    return product;
  }

  @override
  Future<bool> isProductCodeUnique(String code, {String? excludeId}) async {
    final db = await _db;
    final normalized = code.trim().toUpperCase();
    final finder = Finder(
      filter: Filter.equals('normalizedProductCode', normalized),
    );
    final records = await _productsStore.find(db, finder: finder);

    if (records.isEmpty) return true;
    if (excludeId != null &&
        records.length == 1 &&
        records.first.key == excludeId) {
      return true;
    }
    return false;
  }

  @override
  Future<Product> addProduct(Product product) async {
    final db = await _db;
    Product updatedProduct = product;

    await db.transaction((txn) async {
      // 1. Check uniqueness inside transaction
      final isUnique = await _isProductCodeUniqueInTxn(
        txn,
        updatedProduct.productCode,
      );
      if (!isUnique) {
        throw Exception('Product code must be unique');
      }

      // 2. Generate ID
      final newId = _uuid.v4();
      final now = DateTime.now();
      updatedProduct = updatedProduct.copyWith(
        id: newId,
        createdAt: now,
        updatedAt: now,
      );

      // 3. Handle image persistence
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
      }

      // 4. Save JSON
      await _productsStore.record(newId).put(txn, updatedProduct.toJson());
    });

    return updatedProduct;
  }

  @override
  Future<void> addProducts(List<Product> products) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final p in products) {
        await _productsStore.record(p.id).put(txn, p.toJson());
      }
    });
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final db = await _db;
    Product updatedProduct = product.copyWith(updatedAt: DateTime.now());

    await db.transaction((txn) async {
      // 1. Check uniqueness inside transaction
      final isUnique = await _isProductCodeUniqueInTxn(
        txn,
        updatedProduct.productCode,
        excludeId: updatedProduct.id,
      );
      if (!isUnique) {
        throw Exception('Product code must be unique');
      }

      final previousRecord = await _productsStore
          .record(updatedProduct.id)
          .get(txn);
      Product? previousProduct;
      if (previousRecord != null) {
        previousProduct = Product.fromJson(previousRecord);
      }

      // 2. Handle image updates
      if (updatedProduct.imageBytes != null) {
        if (updatedProduct.imageBytes!.isEmpty) {
          // Explicit removal requested
          updatedProduct = updatedProduct.copyWith(
            imageId: '',
            imageBytes: Uint8List(0),
          ); // copyWith handles empty string as nullifier for imageId? Wait, copyWith doesn't nullify if we pass null. It just keeps the old. Let's see...
        } else if (updatedProduct.imageId == null ||
            updatedProduct.imageId!.isEmpty) {
          final newImageId = _uuid.v4();
          await _imagesStore
              .record(newImageId)
              .put(txn, Blob(updatedProduct.imageBytes!));
          await _imagesMetadataStore.record(newImageId).put(txn, {
            'ownerType': 'product',
            'ownerId': updatedProduct.id,
          });
          updatedProduct = updatedProduct.copyWith(imageId: newImageId);
        } else {
          // Update existing image bytes
          await _imagesStore
              .record(updatedProduct.imageId!)
              .put(txn, Blob(updatedProduct.imageBytes!));
        }
      }

      // 3. Cleanup orphaned image
      if (previousProduct != null && previousProduct.imageId != null) {
        if (updatedProduct.imageBytes != null &&
            updatedProduct.imageBytes!.isEmpty) {
          // We are deleting the image
          await _imagesStore.record(previousProduct.imageId!).delete(txn);
          await _imagesMetadataStore
              .record(previousProduct.imageId!)
              .delete(txn);
        } else if (previousProduct.imageId != updatedProduct.imageId) {
          await _imagesStore.record(previousProduct.imageId!).delete(txn);
          await _imagesMetadataStore
              .record(previousProduct.imageId!)
              .delete(txn);
        }
      }

      // 4. Save JSON
      await _productsStore
          .record(updatedProduct.id)
          .put(txn, updatedProduct.toJson());
    });

    return updatedProduct;
  }

  @override
  Future<void> toggleProductStatus(String id, bool isActive) async {
    final db = await _db;
    await db.transaction((txn) async {
      final record = await _productsStore.record(id).get(txn);
      if (record != null) {
        final product = Product.fromJson(record);
        final updatedProduct = product.copyWith(
          isActive: isActive,
          updatedAt: DateTime.now(),
        );
        await _productsStore.record(id).put(txn, updatedProduct.toJson());
      }
    });
  }

  @override
  Future<bool> hasQuotationReferences(String productId) async {
    final db = await _db;
    final records = await _quotationsStore.find(db);
    for (var record in records) {
      final q = Quotation.fromJson(record.value);
      if (q.lineItems.any((item) => item.productId == productId)) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _db;

    // Safety check first
    final hasRefs = await hasQuotationReferences(id);
    if (hasRefs) {
      throw Exception(
        'Cannot delete product because it is referenced in existing quotations. Please deactivate it instead.',
      );
    }

    await db.transaction((txn) async {
      final record = await _productsStore.record(id).get(txn);
      if (record != null) {
        final product = Product.fromJson(record);
        if (product.imageId != null) {
          // Verify ownership before deleting image
          final meta = await _imagesMetadataStore
              .record(product.imageId!)
              .get(txn);
          if (meta != null &&
              meta['ownerType'] == 'product' &&
              meta['ownerId'] == id) {
            await _imagesStore.record(product.imageId!).delete(txn);
            await _imagesMetadataStore.record(product.imageId!).delete(txn);
          }
        }
        await _productsStore.record(id).delete(txn);
      }
    });
  }

  Future<bool> _isProductCodeUniqueInTxn(
    Transaction txn,
    String code, {
    String? excludeId,
  }) async {
    final normalized = code.trim().toUpperCase();
    final finder = Finder(
      filter: Filter.equals('normalizedProductCode', normalized),
    );
    final records = await _productsStore.find(txn, finder: finder);

    if (records.isEmpty) return true;
    if (excludeId != null &&
        records.length == 1 &&
        records.first.key == excludeId) {
      return true;
    }
    return false;
  }
}
