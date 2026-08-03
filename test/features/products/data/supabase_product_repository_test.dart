import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/data/supabase_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';

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
    test('1. Online Sync (Background) down to local cache', () async {
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

      await repo.init(); // Triggers _syncProductsDown
      // Yield to allow background future to complete
      await Future.delayed(const Duration(milliseconds: 50));

      final products = await repo.getAllProducts();
      expect(products.length, greaterThanOrEqualTo(1));

      final syncedProduct = products.firstWhere((p) => p.id == 'remote-1');
      expect(syncedProduct.productCode, 'PROD-R1');
    });

    test('2. Offline fallback', () async {
      repo.overrideIsConnected = false;
      // Should read from Sembast without error
      final products = await repo.getAllProducts();
      expect(products, isA<List<Product>>());

      // Should throw on add
      expect(
        () => repo.addProduct(
          Product(
            id: '',
            productCode: 'PROD-NEW',
            name: 'New',
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
            contains('offline'),
          ),
        ),
      );
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

    test('4. Cache refresh (latest updated_at wins)', () async {
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
        ),
      );

      // Simulate remote update
      repo.serverProducts.firstWhere((p) => p['id'] == p1.id)['name'] =
          'Updated Remotely';
      repo.serverProducts.firstWhere((p) => p['id'] == p1.id)['updated_at'] =
          DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();

      // Trigger sync
      await repo.init();
      await Future.delayed(const Duration(milliseconds: 50));

      final refreshed = await repo.getProductById(p1.id);
      expect(refreshed!.name, 'Updated Remotely');
    });

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
          role: UserRole.salesperson,
          isActive: true,
          createdAt: DateTime.now(),
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

    test(
      '7. Regression: Sync deletion preserves existing quotation snapshot',
      () async {
        repo.overrideIsConnected = true;

        // 1. Add a product to the local cache via repo
        final p = await repo.addProduct(
          Product(
            id: '',
            productCode: 'REG-1',
            name: 'Regression Product',
            category: 'Cat',
            brand: 'Brand',
            sellingPrice: 10,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 2. Create and save a quotation using the QuotationRepository
      final quotationRepo = ServiceLocator().quotationRepository;
      
      final q = Quotation(
        id: '',
        quotationNumber: 'QT-001',
        customerInfo: const CustomerInfo(name: 'Test Cust', phone: '123'),
        lineItems: [
          QuotationLineItem(
            id: 'item-1',
            productId: p.id,
            productCode: p.productCode,
            name: p.name,
            brand: p.brand,
            quantity: 1,
            unitPrice: p.sellingPrice,
          )
        ],
        charges: const QuotationCharges(),
        createdDate: DateTime.now(),
        modifiedDate: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 30)),
        expectedDelivery: DateTime.now().add(const Duration(days: 7)),
        salespersonId: 'ADMIN-001',
      );
      
      final savedQ = await quotationRepo.saveQuotation(q);

        // 3. Simulate remote soft delete
        repo.serverProducts.firstWhere((sp) => sp['id'] == p.id)['deleted_at'] =
            DateTime.now().toUtc().toIso8601String();

        // 4. Trigger sync
        await repo.init();
        await Future.delayed(const Duration(milliseconds: 50));

        // 5. Verify product is gone from local cache
        final localCheck = await repo.getProductById(p.id);
        expect(localCheck, isNull);

        // 6. Verify quotation can still be loaded and contains the product snapshot
      final loadedQ = await quotationRepo.getQuotationByNumber(savedQ.quotationNumber);
      expect(loadedQ, isNotNull);
      expect(loadedQ!.lineItems.length, 1);
      expect(loadedQ.lineItems.first.productId, p.id);
      expect(loadedQ.lineItems.first.name, 'Regression Product');
      },
    );
  });
}
