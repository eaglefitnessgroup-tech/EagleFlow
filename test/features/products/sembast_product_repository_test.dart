import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';

void main() {
  late Database db;
  late SembastProductRepository repository;

  setUp(() async {
    // Open in-memory database for testing
    db = await databaseFactoryMemory.openDatabase(
      'test_products_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(db);

    repository = SembastProductRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Future<Product> addProduct() {
    return repository.addProduct(
      Product(
        id: 'source-id',
        productCode: 'SKU-001',
        name: 'Original name',
        category: 'Original category',
        brand: 'Original brand',
        sellingPrice: 125.5,
        isVatApplicable: true,
        isActive: true,
        description: 'Original description',
        modelNumber: 'MODEL-1',
        unit: 'Nos',
        minStockLevel: 7,
        openingStock: 42,
        notes: 'Existing notes',
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
      ),
    );
  }

  test(
    'init() on empty database does not seed demo products, returns 0 products',
    () async {
      await repository.init();

      final products = await repository.getAllProducts();

      expect(products, isEmpty);
      expect(products.length, 0);
    },
  );

  group('updateProductFields', () {
    test('productName-only update changes only productName', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(productName: 'Updated name'),
      );

      expect(updated.name, 'Updated name');
      expect(updated.category, original.category);
      expect(updated.brand, original.brand);
      expect(updated.sellingPrice, original.sellingPrice);
      expect(updated.unit, original.unit);
      expect(updated.minStockLevel, original.minStockLevel);
      expect(updated.description, original.description);
      expect(updated.isVatApplicable, original.isVatApplicable);
      expect(updated.isActive, original.isActive);
    });

    test('sellingPrice zero is applied', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(sellingPrice: 0),
      );

      expect(updated.sellingPrice, 0);
    });

    test('vatApplicable false is applied', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(vatApplicable: false),
      );

      expect(updated.isVatApplicable, isFalse);
    });

    test('isActive false is applied', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(isActive: false),
      );

      expect(updated.isActive, isFalse);
    });

    test('minStockLevel zero is applied', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(minStockLevel: 0),
      );

      expect(updated.minStockLevel, 0);
    });

    test('null fields do not overwrite existing values', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(productName: 'Updated', category: null),
      );

      expect(updated.name, 'Updated');
      expect(updated.category, original.category);
      expect(updated.description, original.description);
      expect(updated.unit, original.unit);
    });

    test('Product Code and Opening Stock remain unchanged', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(productName: 'Updated'),
      );

      expect(updated.productCode, original.productCode);
      expect(updated.openingStock, original.openingStock);
    });

    test('image reference and bytes remain unchanged', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(productName: 'Updated'),
      );
      final withImage = await repository.getProductWithImage(updated);

      expect(updated.imageId, original.imageId);
      expect(withImage.imageBytes, orderedEquals([1, 2, 3, 4]));
    });

    test('empty patch is a safe no-op', () async {
      final original = await addProduct();

      final updated = await repository.updateProductFields(
        original.id,
        const ProductUpdatePatch(),
      );

      expect(updated.toJson(), original.toJson());
      expect(updated.updatedAt, original.updatedAt);
    });

    test('unknown product ID fails without creating a product', () async {
      final countBefore = (await repository.getAllProducts()).length;

      await expectLater(
        repository.updateProductFields(
          'missing-id',
          const ProductUpdatePatch(productName: 'Should not exist'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Product not found: missing-id'),
          ),
        ),
      );

      expect((await repository.getAllProducts()).length, countBefore);
      expect(await repository.getProductById('missing-id'), isNull);
    });
  });
}
