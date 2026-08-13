import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/stock/data/sembast_stock_repository.dart';
import 'package:eagleflow/features/stock/data/supabase_stock_repository.dart';
import 'package:eagleflow/features/stock/domain/stock_movement.dart';
import 'package:eagleflow/features/products/domain/product.dart';

// Fake Supabase Stock Repository that intercepts network calls for testing
class FakeSupabaseStockRepository extends SupabaseStockRepository {
  List<Map<String, dynamic>> serverMovements = [];
  bool overrideIsConnected = true;
  bool isRpcCalled = false;

  FakeSupabaseStockRepository(super.localCache, super.supabase);

  @override
  bool get isConnectedToServer => overrideIsConnected;

  @override
  Future<List<dynamic>> fetchMovementsFromServer() async {
    if (!overrideIsConnected) throw Exception('Offline');
    return serverMovements;
  }

  @override
  Future<int> fetchBatchCurrentStock(String productId, int openingStock) async {
    if (!overrideIsConnected) throw Exception('Offline');
    isRpcCalled = true;
    return 100; // Fake RPC return value
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late SembastStockRepository localCache;
  late FakeSupabaseStockRepository repo;

  setUp(() async {
    final factory = databaseFactoryMemory;
    db = await factory.openDatabase(
      'test_stock_sync_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(db);

    final locator = ServiceLocator();

    // Simulate Admin login by default
    locator.authController.setCurrentUserForTesting(
      AppUser(
        id: 'ADMIN-001',
        name: 'Anshad',
        username: 'anshad',
        passwordHash: '',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    localCache = SembastStockRepository();
    repo = FakeSupabaseStockRepository(localCache, locator.supabaseService);

    // Seed a product for testing opening stock and negative stock validations
    final productsStore = stringMapStoreFactory.store('products');
    await productsStore
        .record('prod-1')
        .put(
          db,
          Product(
            id: 'prod-1',
            productCode: 'PROD1',
            name: 'Product 1',
            category: 'Cat',
            brand: 'Brand',
            sellingPrice: 10,
            openingStock: 10,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ).toJson(),
        );

    repo.serverMovements = [
      {
        'id': 'remote-m1',
        'product_id': 'prod-1',
        'type': 'stockIn',
        'quantity': 5,
        'reference': 'REF-1',
        'movement_date': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': 'ADMIN-001',
      },
    ];
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await db.close();
  });

  group('SupabaseStockRepository Tests', () {
    test('1. Online movement pull', () async {
      repo.overrideIsConnected = true;
      await repo.init(); // Triggers _syncMovementsDown

      final movements = await repo.getAllMovements();
      expect(movements.length, 1);
      expect(movements.first.id, 'remote-m1');
      expect(movements.first.reference, 'REF-1');
    });

    test('2. Offline read fallback', () async {
      repo.overrideIsConnected = false;
      // Should read from Sembast without error
      final movements = await repo.getAllMovements();
      expect(movements, isEmpty); // Empty initially

      // Should throw on add
      expect(
        () => repo.addMovement(
          StockMovement(
            id: 'm1',
            productId: 'prod-1',
            type: StockMovementType.stockIn,
            quantity: 10,
            reference: 'REF-2',
            movementDate: DateTime.now(),
            createdAt: DateTime.now(),
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

    test('3. Admin Stock In sync', () async {
      repo.overrideIsConnected = true;

      final m = StockMovement(
        id: 'm1',
        productId: 'prod-1',
        type: StockMovementType.stockIn,
        quantity: 10,
        reference: 'REF-IN',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await repo.addMovement(m);

      final movements = await repo.getAllMovements();
      expect(movements.length, 1);
      expect(movements.first.id, 'm1');
    });

    test('4. Admin manual Stock Out sync', () async {
      repo.overrideIsConnected = true;

      final m = StockMovement(
        id: 'm2',
        productId: 'prod-1',
        type: StockMovementType.stockOut,
        quantity: 5,
        reference: 'REF-OUT',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await repo.addMovement(m);

      final movements = await repo.getAllMovements();
      expect(movements.length, 1);
      expect(movements.first.id, 'm2');
    });

    test('5. Salesperson write blocked', () async {
      ServiceLocator().authController.setCurrentUserForTesting(
        AppUser(
          id: 'SALES-001',
          name: 'Ajmal',
          username: 'ajmal',
          passwordHash: '',
          role: UserRole.sales,
          isActive: true,
          createdAt: DateTime.parse('2026-08-01T12:00:00Z'),
          updatedAt: DateTime.parse('2026-08-01T12:00:00Z'),
        ),
      );

      repo.overrideIsConnected = true;
      final m = StockMovement(
        id: 'm1',
        productId: 'prod-1',
        type: StockMovementType.stockIn,
        quantity: 10,
        reference: 'REF-IN',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(
        () => repo.addMovement(m),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    test('6. Negative stock blocked locally', () async {
      repo.overrideIsConnected = true;

      final m = StockMovement(
        id: 'm2',
        productId: 'prod-1',
        type: StockMovementType.stockOut,
        quantity: 15, // Opening stock is 10
        reference: 'REF-OUT-NEG',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(
        () => repo.addMovement(m),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('negative'),
          ),
        ),
      );
    });

    test('7. Remote batch stock refresh (RPC)', () async {
      repo.overrideIsConnected = true;
      repo.isRpcCalled = false;

      final currentStock = await repo.calculateCurrentStock(
        productId: 'prod-1',
        openingStock: 10,
      );

      expect(repo.isRpcCalled, isTrue);
      expect(currentStock, 100); // 100 is returned by our Fake RPC
    });
  });
}
