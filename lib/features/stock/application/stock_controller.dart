import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../domain/stock_repository.dart';
import '../domain/stock_movement.dart';
import '../../products/domain/product.dart';
import '../../../../core/di/service_locator.dart';

class StockController extends ChangeNotifier {
  final StockRepository _repository;

  StockController(this._repository);

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<StockMovement> _movements = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<StockMovement> get movements => _movements;

  String? _lastLoadedProductId;

  Future<void> loadAllMovements() async {
    _setLoading(true);
    _lastLoadedProductId = null;
    try {
      _movements = await _repository.getAllMovements();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load movements. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMovementsForProduct(String productId) async {
    _setLoading(true);
    _lastLoadedProductId = productId;
    try {
      _movements = await _repository.getMovementsForProduct(productId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load movements for product. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<int> getCurrentStock(Product product) async {
    try {
      return await _repository.calculateCurrentStock(
        productId: product.id,
        openingStock: product.openingStock,
      );
    } catch (e) {
      // In case of error (e.g. repo fails), fallback or rethrow
      // We can return 0 or rethrow.
      return 0;
    }
  }

  Future<bool> addStockIn({
    required String productId,
    required int quantity,
    required String reference,
    required DateTime movementDate,
    required String createdBy,
  }) async {
    return _addMovement(
      productId: productId,
      type: StockMovementType.stockIn,
      quantity: quantity,
      reference: reference,
      movementDate: movementDate,
      createdBy: createdBy,
    );
  }

  Future<bool> addStockOut({
    required String productId,
    required int quantity,
    required String reference,
    required DateTime movementDate,
    required String createdBy,
  }) async {
    return _addMovement(
      productId: productId,
      type: StockMovementType.stockOut,
      quantity: quantity,
      reference: reference,
      movementDate: movementDate,
      createdBy: createdBy,
    );
  }

  Future<bool> _addMovement({
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String reference,
    required DateTime movementDate,
    required String createdBy,
  }) async {
    if (_isSaving) return false;
    _setSaving(true);

    try {
      final m = StockMovement(
        id: const Uuid().v4(),
        productId: productId,
        type: type,
        quantity: quantity,
        reference: reference,
        movementDate: movementDate,
        createdAt: DateTime.now().toUtc(),
        createdBy: createdBy,
      );

      await _repository.addMovement(m);
      _errorMessage = null;
      await _refreshCurrentList();

      if (type == StockMovementType.stockOut) {
        await ServiceLocator().reservationCompletionService.completeReservation(productId);
      }

      return true;
    } catch (e) {
      if (e.toString().contains('negative current stock')) {
        _errorMessage =
            'Cannot complete Stock Out: Insufficient stock available.';
      } else {
        _errorMessage = 'Failed to record stock movement. Please try again.';
      }
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteMovement(String movementId) async {
    if (_isSaving) return false;
    _setSaving(true);

    try {
      await _repository.deleteMovement(movementId);
      _errorMessage = null;
      await _refreshCurrentList();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete movement. Please try again.';
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> _refreshCurrentList() async {
    if (_lastLoadedProductId != null) {
      _movements = await _repository.getMovementsForProduct(
        _lastLoadedProductId!,
      );
    } else {
      _movements = await _repository.getAllMovements();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }
}
