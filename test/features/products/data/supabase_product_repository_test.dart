import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';

import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/data/supabase_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';

// Fake Supabase Product Repository that intercepts network calls for testing
class FakeSupabaseProductRepository extends SupabaseProductRepository {
  List<Map<String, dynamic>> serverProducts = [];
  bool overrideIsConnected = true;

  FakeSupabaseProductRepository({
    required super.localCache,
    required super.supabase,
  });

  @override
  bool get isConnectedToServer => overrideIsConnected;

  @override
  Future<List<dynamic>> fetchProductsFromServer() async {
    if (!overrideIsConnected) throw Exception('Offline');
    return serverProducts;
  }

  @override
  Future<void> insertProductToServer(Map<String, dynamic> data) async {
    if (!overrideIsConnected) throw Exception('Offline');
    serverProducts.add(data);
  }

  @override
  Future<void> updateProductOnServer(
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!overrideIsConnected) throw Exception('Offline');
    final index = serverProducts.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      serverProducts[index] = {...serverProducts[index], ...data};
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late SembastProductRepository localCache;
  late FakeSupabaseProductRepository repo;

  setUp(() async {
    final dbName =
        'test_supa_products_${DateTime.now().millisecondsSinceEpoch}.db';
    db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    localCache = SembastProductRepository();

    // Reset AuthController for tests
    final locator = ServiceLocator();
    // Simulate Admin login by default
    locator.authController.setCurrentUserForTesting(
      AppUser(
        id: 'ADMIN-001',
        name: 'Admin',
        username: 'admin',
        passwordHash: '',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Initialize the repository
    repo = FakeSupabaseProductRepository(
      localCache: localCache,
      supabase: locator.supabaseService,
    );
    repo.overrideIsConnected = true;
  });

  tearDown(() async {
    await db.close();
  });

  group('SupabaseProductRepository Tests', () {
    test('1. Online Sync down to local cache on init', () async {
      repo.overrideIsConnected = true;
      repo.serverProducts = [
        {
          'id': 'remote-1',
          'product_code': 'PROD-R1',
          'normalized_product_code': 'PROD-R1',
          'name': 'Remote Product',
          'category': 'Cat',
          'brand': 'Brand',
          'selling_price': 100,
          'is_vat_applicable': true,
          'is_active': true,
          'min_stock_level': 5,
          'opening_stock': 10,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];

      await repo.init(); // Triggers and awaits _syncProductsDown

      final products = await repo.getAllProducts();
      expect(products.length, greaterThanOrEqualTo(1));

      final syncedProduct = products.firstWhere((p) => p.id == 'remote-1');
      expect(syncedProduct.productCode, 'PROD-R1');
    });



    test('3. Duplicate product protection', () async {
      repo.overrideIsConnected = true;

      // Add first product
      await repo.addProduct(
        Product(
          id: '',
          productCode: 'DUP-1',
          name: 'First',
          category: 'Cat',
          brand: 'Brand',
          sellingPrice: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Attempt second with same code
      expect(
        () => repo.addProduct(
          Product(
            id: '',
            productCode: 'dup-1 ', // Test normalization
            name: 'Second',
            category: 'Cat',
            brand: 'Brand',
            sellingPrice: 20,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('unique'),
          ),
        ),
      );
    });

    test(
      '4. Cache refresh via getAllProducts (latest updated_at wins) and keeps server imageId',
      () async {
        repo.overrideIsConnected = true;

        final p1 = await repo.addProduct(
          Product(
            id: '',
            productCode: 'REF-1',
            name: 'Original',
            category: 'Cat',
            brand: 'Brand',
            sellingPrice: 10,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            // Local has no image
          ),
        );

        // Simulate remote update with an image ID
        repo.serverProducts.firstWhere((p) => p['id'] == p1.id)['name'] =
            'Updated Remotely';
        repo.serverProducts.firstWhere((p) => p['id'] == p1.id)['image_id'] =
            'server-image-id';
        repo.serverProducts.firstWhere(
          (p) => p['id'] == p1.id,
        )['updated_at'] = DateTime.now()
            .add(const Duration(days: 1))
            .toUtc()
            .toIso8601String();

        // Trigger sync via getAllProducts
        await repo.getAllProducts();

        final refreshed = await repo.getProductById(p1.id);
        expect(refreshed!.name, 'Updated Remotely');
        expect(refreshed.imageId, 'server-image-id');
      },
    );

    test('5. Admin CRUD sync', () async {
      repo.overrideIsConnected = true;

      // Add
      final p = await repo.addProduct(
        Product(
          id: '',
          productCode: 'CRUD-1',
          name: 'CRUD',
          category: 'Cat',
          brand: 'Brand',
          sellingPrice: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(repo.serverProducts.any((sp) => sp['id'] == p.id), isTrue);

      // Edit
      final updated = p.copyWith(name: 'CRUD Updated');
      final result = await repo.updateProduct(updated);
      expect(result.name, 'CRUD Updated');
      expect(
        repo.serverProducts.firstWhere((sp) => sp['id'] == p.id)['name'],
        'CRUD Updated',
      );

      // Soft Delete
      await repo.deleteProduct(p.id);
      expect(
        repo.serverProducts.firstWhere((sp) => sp['id'] == p.id)['deleted_at'],
        isNotNull,
      );

      // Local cache should be hard deleted
      final localCheck = await repo.getProductById(p.id);
      expect(localCheck, isNull);
    });

    test('6. Sales read-only', () async {
      // Simulate Salesperson login
      ServiceLocator().authController.setCurrentUserForTesting(
        AppUser(
          id: 'SALES-001',
          name: 'Sales',
          username: 'sales',
          passwordHash: '',
          role: UserRole.sales,
          createdAt: DateTime.parse('2026-08-01T12:00:00Z'),
          updatedAt: DateTime.parse('2026-08-01T12:00:00Z'),
        ),
      );

      repo.overrideIsConnected = true;

      // Add should fail
      expect(
        () => repo.addProduct(
          Product(
            id: '',
            productCode: 'SALES-PROD',
            name: 'Sales Prod',
            category: 'Cat',
            brand: 'Brand',
            sellingPrice: 10,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('Unauthorized'),
          ),
        ),
      );

      // Read should succeed
      final products = await repo.getAllProducts();
      expect(products, isA<List<Product>>());
    });


  });
}
