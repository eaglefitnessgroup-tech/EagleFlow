import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../../../core/database/database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/di/service_locator.dart';
import '../domain/stock_movement.dart';
import '../domain/stock_repository.dart';
import 'sembast_stock_repository.dart';

class SupabaseStockRepository implements StockRepository {
  final SembastStockRepository localCache;
  final SupabaseService supabase;

  SupabaseStockRepository(this.localCache, this.supabase);

  final StoreRef<String, Map<String, dynamic>> _movementsStore =
      stringMapStoreFactory.store('stock_movements_store');

  Future<Database> get _db async => await DatabaseService().database;

  bool _syncing = false;

  void _checkAdmin() {
    final user = ServiceLocator().authController.currentUser;
    if (user?.isAdmin != true) {
      throw Exception(
        'Unauthorized: Only admins can perform manual stock movements.',
      );
    }
  }

  @visibleForTesting
  bool get isConnectedToServer => supabase.isConnected;

  Future<void> init() async {
    if (!isConnectedToServer) return;
    await _syncMovementsDown();
  }

  @visibleForTesting
  Future<List<dynamic>> fetchMovementsFromServer() async {
    final client = supabase.client;
    if (client == null) return [];

    // Fetch all stock movements
    final response = await client
        .from('stock_movements')
        .select()
        .order('movement_date', ascending: false)
        .order('created_at', ascending: false);
    return response as List<dynamic>;
  }

  Future<void> _syncMovementsDown() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final serverMovements = await fetchMovementsFromServer();

      final db = await _db;
      await db.transaction((txn) async {
        for (var row in serverMovements) {
          final serverMovement = _fromSupabase(row);
          final localRecord = await _movementsStore
              .record(serverMovement.id)
              .get(txn);

          if (localRecord == null) {
            await _movementsStore
                .record(serverMovement.id)
                .put(txn, serverMovement.toJson());
          } else {
            final localMovement = StockMovement.fromJson(localRecord);
            // Never allow local overwrite of newer remote movements
            if (serverMovement.createdAt.isAfter(localMovement.createdAt)) {
              await _movementsStore
                  .record(serverMovement.id)
                  .put(txn, serverMovement.toJson());
            }
          }
        }
      });
    } catch (e) {
      // Ignore sync errors
    } finally {
      _syncing = false;
    }
  }

  StockMovement _fromSupabase(Map<String, dynamic> row) {
    return StockMovement(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      type: StockMovementType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => StockMovementType.stockIn,
      ),
      quantity: row['quantity'] as int,
      reference: row['reference'] as String,
      movementDate: row['movement_date'] != null
          ? DateTime.parse(row['movement_date'] as String)
          : DateTime.now(),
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      createdBy: row['created_by'] as String? ?? 'system',
    );
  }

  @override
  Future<StockMovement> addMovement(StockMovement movement) async {
    _checkAdmin();

    if (!isConnectedToServer) {
      throw Exception('Cannot perform manual stock movements offline.');
    }

    // Negative stock is validated locally first
    await localCache.addMovement(movement);

    try {
      final client = supabase.client;
      if (client != null) {
        await client.from('stock_movements').insert({
          'id': movement.id,
          'product_id': movement.productId,
          'type': movement.type.name,
          'quantity': movement.quantity,
          'reference': movement.reference,
          'movement_date': movement.movementDate.toUtc().toIso8601String(),
          'created_at': movement.createdAt.toUtc().toIso8601String(),
          'created_by': movement.createdBy,
        });
      }
    } catch (e) {
      // If remote insert fails, delete the locally added movement to rollback.
      await localCache.deleteMovement(movement.id);
      throw Exception(
        'Failed to sync stock movement to remote. Please try again.',
      );
    }

    return movement;
  }

  @override
  Future<List<StockMovement>> getMovementsForProduct(String productId) async {
    return localCache.getMovementsForProduct(productId);
  }

  @override
  Future<List<StockMovement>> getAllMovements() async {
    return localCache.getAllMovements();
  }

  @override
  Future<void> deleteMovement(String movementId) async {
    _checkAdmin();
    // Movements are immutable
    throw Exception('Stock movements are immutable. Deletion is not allowed.');
  }

  @override
  Future<int> calculateCurrentStock({
    required String productId,
    required int openingStock,
  }) async {
    if (isConnectedToServer) {
      return fetchBatchCurrentStock(productId, openingStock);
    }
    return localCache.calculateCurrentStock(
      productId: productId,
      openingStock: openingStock,
    );
  }

  @visibleForTesting
  Future<int> fetchBatchCurrentStock(String productId, int openingStock) async {
    try {
      final client = supabase.client;
      if (client == null) {
        return localCache.calculateCurrentStock(
          productId: productId,
          openingStock: openingStock,
        );
      }

      final response = await client.rpc(
        'get_current_stock',
        params: {'p_product_id': productId},
      );
      if (response != null && response is int) {
        return response;
      }
      return localCache.calculateCurrentStock(
        productId: productId,
        openingStock: openingStock,
      );
    } catch (e) {
      return localCache.calculateCurrentStock(
        productId: productId,
        openingStock: openingStock,
      );
    }
  }
}
