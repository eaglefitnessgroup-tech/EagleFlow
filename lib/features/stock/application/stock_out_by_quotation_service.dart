import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../quotations/domain/quotation.dart';
import '../../quotations/data/quotation_repository.dart';
import '../domain/stock_movement.dart';

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
  final StoreRef<String, Map<String, dynamic>> _movementsStore =
      stringMapStoreFactory.store('stock_movements_store');
  final StoreRef<String, Map<String, dynamic>> _productsStore =
      stringMapStoreFactory.store('products');
  final StoreRef<String, Map<String, dynamic>> _quotationsStore =
      stringMapStoreFactory.store('quotations');
  final Uuid _uuid = const Uuid();

  StockOutByQuotationService({required this.quotationRepository});

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

    // 1. Load quotation
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

    // 2. Identify eligible items
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

    final db = await DatabaseService().database;

    try {
      final updatedQuotation = await db.transaction((txn) async {
        // Re-verify quotation state inside transaction
        final qtRecord = await _quotationsStore.record(quotation.id).get(txn);
        if (qtRecord == null) {
          throw Exception('Quotation not found during transaction.');
        }
        final currentQt = Quotation.fromJson(qtRecord);
        if (currentQt.isStockOutProcessed) {
          throw Exception('Quotation was processed by another operation.');
        }

        final movementsToSave = <StockMovement>[];

        // 4. Validate stock for all eligible items before any write
        for (var item in eligibleItems) {
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

          int currentStock = openingStock;
          for (var record in existingMovements) {
            final m = StockMovement.fromJson(record.value);
            if (m.type == StockMovementType.stockIn) {
              currentStock += m.quantity;
            } else {
              currentStock -= m.quantity;
            }
          }

          if (currentStock < item.quantity) {
            throw Exception(
              'Insufficient stock for "${item.name}". Available: $currentStock, Required: ${item.quantity}.',
            );
          }

          // Create the movement
          final movement = StockMovement(
            id: _uuid.v4(),
            productId: productId,
            type: StockMovementType.stockOut,
            quantity: item.quantity,
            reference: 'Reason: Quotation Stock Out | Quotation: $cleanNumber',
            movementDate: DateTime.now().toUtc(),
            createdAt: DateTime.now().toUtc(),
            createdBy: 'Admin',
          );
          movementsToSave.add(movement);
        }

        // 5. Atomic save - Write all movements
        for (var movement in movementsToSave) {
          await _movementsStore.record(movement.id).put(txn, movement.toJson());
        }

        // Update quotation
        final modifiedQt = currentQt.copyWith(
          isStockOutProcessed: true,
          modifiedDate: DateTime.now(),
        );
        await _quotationsStore
            .record(modifiedQt.id)
            .put(txn, modifiedQt.toJson());

        return modifiedQt;
      });

      return StockOutByQuotationResult(
        success: true,
        message:
            'Successfully processed ${eligibleItems.length} items for stock out.',
        quotation: updatedQuotation,
        deductedCount: eligibleItems.length,
      );
    } catch (e) {
      return StockOutByQuotationResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
        quotation: quotation,
      );
    }
  }
}
