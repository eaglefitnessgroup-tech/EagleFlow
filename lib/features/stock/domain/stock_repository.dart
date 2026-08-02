import '../domain/stock_movement.dart';

abstract class StockRepository {
  Future<StockMovement> addMovement(StockMovement movement);
  Future<List<StockMovement>> getMovementsForProduct(String productId);
  Future<List<StockMovement>> getAllMovements();
  Future<void> deleteMovement(String movementId);
  Future<int> calculateCurrentStock({
    required String productId,
    required int openingStock,
  });
}
