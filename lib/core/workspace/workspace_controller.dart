import 'package:flutter/foundation.dart';

import '../../features/products/application/product_master_controller.dart';
import '../../features/products/data/supabase_product_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/quotations/data/quotation_repository.dart';
import '../../features/quotations/data/supabase_quotation_repository.dart';

enum WorkspaceState {
  initializing,
  authenticatedDataLoading,
  ready,
  failed,
  unauthenticated,
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required ProductRepository productRepository,
    required ProductMasterController productController,
    required QuotationRepository quotationRepository,
  }) : _productRepository = productRepository,
       _productController = productController,
       _quotationRepository = quotationRepository;

  final ProductRepository _productRepository;
  final ProductMasterController _productController;
  final QuotationRepository _quotationRepository;

  WorkspaceState _state = WorkspaceState.initializing;
  String? _userId;
  Object? _error;
  Future<void>? _activeInitialization;
  int _generation = 0;

  WorkspaceState get state => _state;
  String? get userId => _userId;
  Object? get error => _error;
  bool get isReady => _state == WorkspaceState.ready;

  Future<void> initializeForUser(String userId) {
    final active = _activeInitialization;
    if (active != null && _userId == userId) return active;

    final generation = ++_generation;
    _userId = userId;
    _error = null;
    _state = WorkspaceState.authenticatedDataLoading;
    notifyListeners();

    final initialization = _runInitialization(userId, generation);
    _activeInitialization = initialization;
    return initialization;
  }

  Future<void> _runInitialization(String userId, int generation) async {
    try {
      await _initialize(userId, generation);
    } finally {
      final initialization = _activeInitialization;
      if (generation == _generation && initialization != null) {
        _activeInitialization = null;
      }
    }
  }

  Future<void> _initialize(String userId, int generation) async {
    try {
      await _productRepository.init();
      _ensureCurrent(userId, generation);

      await _productController.loadProducts();
      _ensureCurrent(userId, generation);

      await _quotationRepository.getAllQuotations();
      _ensureCurrent(userId, generation);

      _state = WorkspaceState.ready;
      notifyListeners();
    } catch (error) {
      if (_isCurrent(userId, generation)) {
        _error = error;
        _state = WorkspaceState.failed;
        notifyListeners();
      }
      rethrow;
    }
  }

  void reset() {
    _generation++;
    _activeInitialization = null;
    _userId = null;
    _error = null;
    _state = WorkspaceState.unauthenticated;

    _productController.reset();
    if (_productRepository is SupabaseProductRepository) {
      _productRepository.invalidateSession();
    }
    if (_quotationRepository is SupabaseQuotationRepository) {
      _quotationRepository.invalidateSession();
    }
    notifyListeners();
  }

  bool _isCurrent(String userId, int generation) =>
      generation == _generation && _userId == userId;

  void _ensureCurrent(String userId, int generation) {
    if (!_isCurrent(userId, generation)) {
      throw StateError('Workspace initialization was superseded.');
    }
  }
}
