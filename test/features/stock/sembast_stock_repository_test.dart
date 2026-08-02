import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:uuid/uuid.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/stock/data/sembast_stock_repository.dart';
import 'package:eagleflow/features/stock/domain/stock_movement.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';

void main() {
  group('SembastStockRepository Tests', () {
    late Database db;
    late SembastStockRepository repo;
    late SembastProductRepository productRepo;

    setUp(() async {
      final dbName =
          'test_stock_repo_${DateTime.now().millisecondsSinceEpoch}.db';
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);
      repo = SembastStockRepository();
      productRepo = SembastProductRepository();
      // productRepo init is not needed here as we use it just to seed a product
    });

    tearDown(() async {
      await db.close();
    });

    Future<Product> seedProduct(int openingStock) async {
      final p = Product(
        id: '',
        productCode: 'PROD-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Product',
        category: 'Cat',
        brand: 'Brand',
        sellingPrice: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        openingStock: openingStock,
      );
      return await productRepo.addProduct(p);
    }

    test('add stock in', () async {
      final p = await seedProduct(0);
      final m = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 10,
        reference: 'Initial',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await repo.addMovement(m);

      final stock = await repo.calculateCurrentStock(
        productId: p.id,
        openingStock: p.openingStock,
      );
      expect(stock, 10);
    });

    test('add stock out and negative stock prevention', () async {
      final p = await seedProduct(5); // Opening stock = 5

      // Valid stock out
      final m1 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockOut,
        quantity: 3,
        reference: 'Sale',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await repo.addMovement(m1);
      var stock = await repo.calculateCurrentStock(
        productId: p.id,
        openingStock: p.openingStock,
      );
      expect(stock, 2);

      // Invalid stock out (would go to -1)
      final m2 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockOut,
        quantity: 3,
        reference: 'Sale 2',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(() => repo.addMovement(m2), throwsA(isA<Exception>()));

      // Stock remains unchanged
      stock = await repo.calculateCurrentStock(
        productId: p.id,
        openingStock: p.openingStock,
      );
      expect(stock, 2);
    });

    test('movement order newest first', () async {
      final p = await seedProduct(0);

      final now = DateTime.now();

      final m1 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 5,
        reference: 'M1',
        movementDate: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
      );

      final m2 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 5,
        reference: 'M2',
        movementDate: now,
        createdAt: now,
      );

      final m3 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 5,
        reference: 'M3',
        movementDate: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
      );

      await repo.addMovement(m1);
      await repo.addMovement(m2);
      await repo.addMovement(m3);

      final movements = await repo.getMovementsForProduct(p.id);
      expect(movements.length, 3);
      expect(movements[0].reference, 'M2');
      expect(movements[1].reference, 'M3');
      expect(movements[2].reference, 'M1');
    });

    test('persistence after database reopen', () async {
      final dbName =
          'test_persistence_${DateTime.now().millisecondsSinceEpoch}.db';
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);

      final p = await seedProduct(0);
      final m = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 25,
        reference: 'Restock',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await repo.addMovement(m);

      await db.close();

      // Reopen
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);

      final movements = await repo.getMovementsForProduct(p.id);
      expect(movements.length, 1);
      expect(movements.first.quantity, 25);
    });

    test('delete movement recalculates stock correctly', () async {
      final p = await seedProduct(0);

      final m1 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 10,
        reference: 'M1',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await repo.addMovement(m1);

      final m2 = StockMovement(
        id: const Uuid().v4(),
        productId: p.id,
        type: StockMovementType.stockIn,
        quantity: 5,
        reference: 'M2',
        movementDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await repo.addMovement(m2);

      var stock = await repo.calculateCurrentStock(
        productId: p.id,
        openingStock: p.openingStock,
      );
      expect(stock, 15);

      await repo.deleteMovement(m1.id);

      stock = await repo.calculateCurrentStock(
        productId: p.id,
        openingStock: p.openingStock,
      );
      expect(stock, 5);
    });
  });
}
