import 'package:sembast/sembast.dart';
import '../../../core/database/database_service.dart';
import '../domain/stock_movement.dart';
import '../domain/stock_repository.dart';

class SembastStockRepository implements StockRepository {
  final StoreRef<String, Map<String, dynamic>> _movementsStore =
      stringMapStoreFactory.store('stock_movements_store');
  final StoreRef<String, Map<String, dynamic>> _productsStore =
      stringMapStoreFactory.store('products');

  Future<Database> get _db async => await DatabaseService().database;

  @override
  Future<StockMovement> addMovement(StockMovement movement) async {
    if (movement.productId.trim().isEmpty) {
      throw ArgumentError('Product ID must not be empty');
    }
    if (movement.reference.trim().isEmpty) {
      throw ArgumentError('Reference must not be empty');
    }

    final db = await _db;

    await db.transaction((txn) async {
      // 1. Fetch Product to get Opening Stock
      final productRecord = await _productsStore
          .record(movement.productId)
          .get(txn);
      if (productRecord == null) {
        throw Exception('Product not found');
      }
      final openingStock = productRecord['openingStock'] as int? ?? 0;

      // 2. Fetch all current movements to calculate Current Stock
      final finder = Finder(
        filter: Filter.equals('productId', movement.productId),
      );
      final existingRecords = await _movementsStore.find(txn, finder: finder);

      int currentStock = openingStock;
      for (var record in existingRecords) {
        final m = StockMovement.fromJson(record.value);
        if (m.type == StockMovementType.stockIn) {
          currentStock += m.quantity;
        } else {
          currentStock -= m.quantity;
        }
      }

      // 3. Validate negative stock prevention
      if (movement.type == StockMovementType.stockOut) {
        if (currentStock - movement.quantity < 0) {
          throw Exception('Stock out would result in negative current stock');
        }
      }

      // 4. Save
      await _movementsStore.record(movement.id).put(txn, movement.toJson());
    });

    return movement;
  }

  @override
  Future<List<StockMovement>> getMovementsForProduct(String productId) async {
    final db = await _db;
    final finder = Finder(
      filter: Filter.equals('productId', productId),
      sortOrders: [
        SortOrder('movementDate', false),
        SortOrder('createdAt', false),
      ],
    );
    final records = await _movementsStore.find(db, finder: finder);
    return records.map((r) => StockMovement.fromJson(r.value)).toList();
  }

  @override
  Future<List<StockMovement>> getAllMovements() async {
    final db = await _db;
    final finder = Finder(
      sortOrders: [
        SortOrder('movementDate', false),
        SortOrder('createdAt', false),
      ],
    );
    final records = await _movementsStore.find(db, finder: finder);
    return records.map((r) => StockMovement.fromJson(r.value)).toList();
  }

  @override
  Future<void> deleteMovement(String movementId) async {
    final db = await _db;
    await _movementsStore.record(movementId).delete(db);
  }

  @override
  Future<int> calculateCurrentStock({
    required String productId,
    required int openingStock,
  }) async {
    final movements = await getMovementsForProduct(productId);
    int currentStock = openingStock;
    for (var m in movements) {
      if (m.type == StockMovementType.stockIn) {
        currentStock += m.quantity;
      } else {
        currentStock -= m.quantity;
      }
    }
    return currentStock;
  }
}
