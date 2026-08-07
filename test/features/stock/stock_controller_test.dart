import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/stock/application/stock_controller.dart';
import 'package:eagleflow/features/stock/domain/stock_movement.dart';
import 'package:eagleflow/features/stock/domain/stock_repository.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';

class MockStockRepository implements StockRepository {
  List<StockMovement> movements = [];
  int currentStock = 0;
  bool shouldThrow = false;
  bool shouldThrowNegativeStock = false;
  int addDelayMs = 0;

  @override
  Future<StockMovement> addMovement(StockMovement movement) async {
    if (addDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: addDelayMs));
    }
    if (shouldThrow) {
      throw Exception('Database error');
    }
    if (shouldThrowNegativeStock &&
        movement.type == StockMovementType.stockOut) {
      throw Exception('Stock out would result in negative current stock');
    }
    movements.insert(0, movement); // insert at top for newest-first simulation
    return movement;
  }

  @override
  Future<int> calculateCurrentStock({
    required String productId,
    required int openingStock,
  }) async {
    if (shouldThrow) {
      throw Exception('Database error');
    }
    return currentStock;
  }

  @override
  Future<void> deleteMovement(String movementId) async {
    if (shouldThrow) {
      throw Exception('Database error');
    }
    movements.removeWhere((m) => m.id == movementId);
  }

  @override
  Future<List<StockMovement>> getAllMovements() async {
    if (shouldThrow) {
      throw Exception('Database error');
    }
    return movements;
  }

  @override
  Future<List<StockMovement>> getMovementsForProduct(String productId) async {
    if (shouldThrow) {
      throw Exception('Database error');
    }
    return movements.where((m) => m.productId == productId).toList();
  }
}

void main() {
  group('StockController Tests', () {
    late MockStockRepository repo;
    late StockController controller;

    late Database db;

    setUp(() async {
      ServiceLocator.resetForTesting();
      final dbName = 'test_stock_controller_${DateTime.now().microsecondsSinceEpoch}.db';
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);
      await ServiceLocator().init();

      repo = MockStockRepository();
      controller = StockController(repo);
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      await DatabaseService().closeAndResetForTesting();
      ServiceLocator.resetForTesting();
    });

    test('load movements and loading state transitions', () async {
      repo.movements = [
        StockMovement(
          id: '1',
          productId: 'p1',
          type: StockMovementType.stockIn,
          quantity: 10,
          reference: 'Ref 1',
          movementDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      expect(controller.isLoading, false);
      expect(controller.movements.isEmpty, true);

      final future = controller.loadAllMovements();
      expect(controller.isLoading, true);

      await future;

      expect(controller.isLoading, false);
      expect(controller.movements.length, 1);
      expect(controller.errorMessage, isNull);
    });

    test('error state transition on load failure', () async {
      repo.shouldThrow = true;

      await controller.loadAllMovements();

      expect(controller.isLoading, false);
      expect(controller.movements.isEmpty, true);
      expect(
        controller.errorMessage,
        contains('Failed to load movements. Please try again.'),
      );
    });

    test('add Stock In updates list and saving state', () async {
      final future = controller.addStockIn(
        productId: 'p1',
        quantity: 20,
        reference: 'Restock',
        movementDate: DateTime.now(),
        createdBy: 'admin',
      );

      expect(controller.isSaving, true);

      final result = await future;

      expect(result, true);
      expect(controller.isSaving, false);
      expect(controller.movements.length, 1);
      expect(controller.movements.first.quantity, 20);
      expect(controller.movements.first.type, StockMovementType.stockIn);
      expect(controller.errorMessage, isNull);
    });

    test('add Stock Out updates list and saving state', () async {
      repo.currentStock = 10;
      final result = await controller.addStockOut(
        productId: 'p1',
        quantity: 5,
        reference: 'Sale',
        movementDate: DateTime.now(),
        createdBy: 'admin',
      );

      expect(result, true);
      expect(controller.movements.length, 1);
      expect(controller.movements.first.quantity, 5);
      expect(controller.movements.first.type, StockMovementType.stockOut);
      expect(controller.errorMessage, isNull);
    });

    test('negative stock error handling formats user message', () async {
      repo.shouldThrowNegativeStock = true;

      final result = await controller.addStockOut(
        productId: 'p1',
        quantity: 100,
        reference: 'Huge Sale',
        movementDate: DateTime.now(),
        createdBy: 'admin',
      );

      expect(result, false);
      expect(controller.movements.isEmpty, true);
      expect(controller.errorMessage, contains('Insufficient stock available'));
    });

    test('double-submit prevention', () async {
      repo.addDelayMs = 50;

      final future1 = controller.addStockIn(
        productId: 'p1',
        quantity: 10,
        reference: 'R1',
        movementDate: DateTime.now(),
        createdBy: 'admin',
      );

      final future2 = controller.addStockIn(
        productId: 'p1',
        quantity: 20,
        reference: 'R2',
        movementDate: DateTime.now(),
        createdBy: 'admin',
      );

      final results = await Future.wait([future1, future2]);

      expect(results[0], true); // First one succeeds
      expect(results[1], false); // Second one fails due to isSaving

      expect(repo.movements.length, 1); // Only 1 was inserted
      expect(repo.movements.first.quantity, 10);
    });

    test('delete movement and refresh list', () async {
      repo.movements = [
        StockMovement(
          id: '1',
          productId: 'p1',
          type: StockMovementType.stockIn,
          quantity: 10,
          reference: 'Ref 1',
          movementDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];
      await controller.loadAllMovements();
      expect(controller.movements.length, 1);

      final result = await controller.deleteMovement('1');

      expect(result, true);
      expect(controller.movements.isEmpty, true);
      expect(repo.movements.isEmpty, true);
    });
  });
}
