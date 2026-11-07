import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../quotations/data/quotation_repository.dart';
import '../../quotations/domain/quotation.dart';
import '../domain/stock_movement.dart';

typedef StockOutByQuotationRemoteProcessor =
    Future<Object?> Function(String quotationNumber);

class StockOutByQuotationResult {
  final bool success;
  final String message;
  final Quotation? quotation;
  final int deductedCount;

  StockOutByQuotationResult({
    required this.success,
    required this.message,
    this.quotation,
    this.deductedCount = 0,
  });
}

class StockOutByQuotationService {
  final QuotationRepository quotationRepository;
  final SupabaseService _supabase;
  final StockOutByQuotationRemoteProcessor? _remoteProcessor;
  final StoreRef<String, Map<String, dynamic>> _movementsStore =
      stringMapStoreFactory.store('stock_movements_store');
  final StoreRef<String, Map<String, dynamic>> _productsStore =
      stringMapStoreFactory.store('products');
  final StoreRef<String, Map<String, dynamic>> _quotationsStore =
      stringMapStoreFactory.store('quotations');
  final StoreRef<String, Map<String, dynamic>> _reservationsStore =
      stringMapStoreFactory.store('reservations');
  final Uuid _uuid = const Uuid();

  StockOutByQuotationService({
    required this.quotationRepository,
    SupabaseService? supabaseService,
    @visibleForTesting this._remoteProcessor,
  }) : _supabase = supabaseService ?? SupabaseService();

  Future<StockOutByQuotationResult> processStockOut(
    String quotationNumber,
  ) async {
    final cleanNumber = quotationNumber.trim();
    if (cleanNumber.isEmpty) {
      return StockOutByQuotationResult(
        success: false,
        message: 'Quotation number cannot be empty.',
      );
    }

    if (_supabase.isInitialized && !_supabase.isConnected) {
      return StockOutByQuotationResult(
        success: false,
        message: 'Cannot process stock out while offline.',
      );
    }

    final quotation = await quotationRepository.getQuotationByNumber(
      cleanNumber,
    );
    if (quotation == null) {
      return StockOutByQuotationResult(
        success: false,
        message: 'Quotation not found.',
      );
    }

    if (quotation.isStockOutProcessed) {
      return StockOutByQuotationResult(
        success: false,
        message: 'This quotation has already been processed for stock out.',
        quotation: quotation,
      );
    }

    final eligibleItems = quotation.lineItems
        .where(
          (item) =>
              !item.isCustom &&
              item.productId != null &&
              item.productId!.trim().isNotEmpty &&
              item.quantity > 0,
        )
        .toList();

    if (eligibleItems.isEmpty) {
      return StockOutByQuotationResult(
        success: false,
        message: 'No eligible stock items found in this quotation.',
        quotation: quotation,
      );
    }

    if (_remoteProcessor != null || _supabase.client != null) {
      return _processRemotely(cleanNumber, quotation);
    }

    return _processLocally(cleanNumber, quotation);
  }

  Future<StockOutByQuotationResult> _processRemotely(
    String quotationNumber,
    Quotation quotation,
  ) async {
    try {
      final rawResponse = _remoteProcessor != null
          ? await _remoteProcessor(quotationNumber)
          : await _supabase.client!.rpc(
              'process_quotation_stock_out',
              params: {'p_quotation_number': quotationNumber},
            );

      if (rawResponse is! Map) {
        throw Exception('Stock-out RPC returned an invalid response.');
      }
      final response = Map<String, dynamic>.from(rawResponse);
      if (response['error'] != null) {
        throw Exception(response['error']);
      }
      if (response['success'] != true) {
        throw Exception('Stock-out RPC did not confirm success.');
      }

      final processedAt = _parseDateTime(response['processed_at']);
      final updatedQuotation = quotation.copyWith(
        isStockOutProcessed: true,
        modifiedDate: processedAt ?? DateTime.now(),
      );

      try {
        await _applyRemoteResultToLocalCache(
          updatedQuotation,
          response['movements'],
        );
      } catch (error) {
        // The server transaction is authoritative. A realtime/sync refresh can
        // repair a local cache failure without risking a duplicate deduction.
        debugPrint('Stock-out local cache refresh failed: $error');
      }

      if (response['already_processed'] == true) {
        return StockOutByQuotationResult(
          success: false,
          message: 'This quotation has already been processed for stock out.',
          quotation: updatedQuotation,
        );
      }

      final deductedCount = (response['deducted_count'] as num?)?.toInt() ?? 0;
      return StockOutByQuotationResult(
        success: true,
        message: 'Successfully processed $deductedCount items for stock out.',
        quotation: updatedQuotation,
        deductedCount: deductedCount,
      );
    } catch (error) {
      return StockOutByQuotationResult(
        success: false,
        message: _remoteFailureMessage(error),
        quotation: quotation,
      );
    }
  }

  Future<void> _applyRemoteResultToLocalCache(
    Quotation updatedQuotation,
    Object? rawMovements,
  ) async {
    final movements = <StockMovement>[];
    if (rawMovements is List) {
      for (final rawMovement in rawMovements) {
        if (rawMovement is! Map) continue;
        final movement = Map<String, dynamic>.from(rawMovement);
        movements.add(
          StockMovement(
            id: movement['id'].toString(),
            productId: movement['product_id'].toString(),
            type: StockMovementType.stockOut,
            quantity: (movement['quantity'] as num).toInt(),
            reference: movement['reference'].toString(),
            movementDate:
                _parseDateTime(movement['movement_date']) ?? DateTime.now(),
            createdAt: _parseDateTime(movement['created_at']) ?? DateTime.now(),
            createdBy: movement['created_by']?.toString() ?? 'Admin',
          ),
        );
      }
    }

    final productIds = updatedQuotation.lineItems
        .where(
          (item) =>
              !item.isCustom &&
              item.productId != null &&
              item.productId!.trim().isNotEmpty &&
              item.quantity > 0,
        )
        .map((item) => item.productId!)
        .toSet();

    final db = await DatabaseService().database;
    await db.transaction((txn) async {
      for (final movement in movements) {
        await _movementsStore.record(movement.id).put(txn, movement.toJson());
      }

      await _quotationsStore
          .record(updatedQuotation.id)
          .put(txn, updatedQuotation.toJson());

      final activeReservations = await _reservationsStore.find(
        txn,
        finder: Finder(filter: Filter.equals('status', 'ACTIVE')),
      );
      for (final record in activeReservations) {
        if (!productIds.contains(record.value['productId'])) continue;
        final updated = Map<String, dynamic>.from(record.value)
          ..['status'] = 'COMPLETED'
          ..['updatedAt'] = updatedQuotation.modifiedDate.toIso8601String();
        await _reservationsStore.record(record.key).put(txn, updated);
      }
    });
  }

  Future<StockOutByQuotationResult> _processLocally(
    String quotationNumber,
    Quotation quotation,
  ) async {
    final eligibleItems = quotation.lineItems
        .where(
          (item) =>
              !item.isCustom &&
              item.productId != null &&
              item.productId!.trim().isNotEmpty &&
              item.quantity > 0,
        )
        .toList();
    final db = await DatabaseService().database;

    try {
      final updatedQuotation = await db.transaction((txn) async {
        final qtRecord = await _quotationsStore.record(quotation.id).get(txn);
        if (qtRecord == null) {
          throw Exception('Quotation not found during transaction.');
        }
        final currentQt = Quotation.fromJson(qtRecord);
        if (currentQt.isStockOutProcessed) {
          throw Exception('Quotation was processed by another operation.');
        }

        final movementsToSave = <StockMovement>[];

        for (final item in eligibleItems) {
          final productId = item.productId!;
          final productRecord = await _productsStore.record(productId).get(txn);
          if (productRecord == null) {
            throw Exception('Product "${item.name}" not found in database.');
          }
          final openingStock = productRecord['openingStock'] as int? ?? 0;

          final finder = Finder(filter: Filter.equals('productId', productId));
          final existingMovements = await _movementsStore.find(
            txn,
            finder: finder,
          );

          var currentStock = openingStock;
          for (final record in existingMovements) {
            final movement = StockMovement.fromJson(record.value);
            if (movement.type == StockMovementType.stockIn) {
              currentStock += movement.quantity;
            } else {
              currentStock -= movement.quantity;
            }
          }

          if (currentStock < item.quantity) {
            throw Exception(
              'Insufficient stock for "${item.name}". Available: $currentStock, Required: ${item.quantity}.',
            );
          }

          final now = DateTime.now().toUtc();
          movementsToSave.add(
            StockMovement(
              id: _uuid.v4(),
              productId: productId,
              type: StockMovementType.stockOut,
              quantity: item.quantity,
              reference:
                  'Reason: Quotation Stock Out | Quotation: $quotationNumber',
              movementDate: now,
              createdAt: now,
              createdBy: 'Admin',
            ),
          );
        }

        for (final movement in movementsToSave) {
          await _movementsStore.record(movement.id).put(txn, movement.toJson());
        }

        final modifiedQt = currentQt.copyWith(
          isStockOutProcessed: true,
          modifiedDate: DateTime.now(),
        );
        await _quotationsStore
            .record(modifiedQt.id)
            .put(txn, modifiedQt.toJson());

        return modifiedQt;
      });

      for (final item in eligibleItems) {
        await ServiceLocator().reservationCompletionService.completeReservation(
          item.productId!,
        );
      }

      return StockOutByQuotationResult(
        success: true,
        message:
            'Successfully processed ${eligibleItems.length} items for stock out.',
        quotation: updatedQuotation,
        deductedCount: eligibleItems.length,
      );
    } catch (error) {
      return StockOutByQuotationResult(
        success: false,
        message: error.toString().replaceFirst('Exception: ', ''),
        quotation: quotation,
      );
    }
  }

  DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _remoteFailureMessage(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
