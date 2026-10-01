import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../products/application/product_master_controller.dart';
import '../../products/domain/product.dart';
import '../domain/quick_quote_candidate_pool.dart';
import '../domain/quick_quote_mapping_repository.dart';
import '../domain/quick_quote_product_mapping.dart';
import '../domain/quick_quote_request.dart';
import '../domain/quick_quote_result.dart';
import '../domain/quick_quote_rules.dart';
import 'quick_quote_candidate_preparer.dart';
import 'quick_quote_optimizer.dart';

enum QuickQuoteControllerStatus { loading, ready, generating, result, error }

class QuickQuoteController extends ChangeNotifier {
  QuickQuoteController({
    required this.productController,
    required this.mappingRepository,
    QuickQuoteCandidatePreparer? candidatePreparer,
    QuickQuoteOptimizer? optimizer,
  }) : _candidatePreparer = candidatePreparer ?? QuickQuoteCandidatePreparer(),
       _optimizer = optimizer ?? const QuickQuoteOptimizer();

  final ProductMasterController productController;
  final QuickQuoteMappingRepository mappingRepository;
  final QuickQuoteCandidatePreparer _candidatePreparer;
  final QuickQuoteOptimizer _optimizer;

  QuickQuoteControllerStatus _status = QuickQuoteControllerStatus.loading;
  List<Product> _activeProducts = const [];
  List<QuickQuoteProductMapping> _mappings = const [];
  List<String> _strengthBrands = const [];
  Map<QuickQuoteCardioRole, List<Product>> _cardioCandidates = const {};
  final Map<QuickQuoteCardioRole, String?> _selectedCardioProductIds = {};
  String? _strengthBrand;
  String _premierPinSeriesPrefix = 'APN';
  String _premierPlateSeriesPrefix = 'APL';
  QuickQuoteCandidatePool? _availabilityPool;
  QuickQuoteResult? _result;
  QuickQuoteRequest? _lastRequest;
  String? _errorMessage;
  String? _mappingNotice;
  String? _generationError;
  String? _budgetError;

  QuickQuoteControllerStatus get status => _status;
  bool get isLoading => _status == QuickQuoteControllerStatus.loading;
  bool get isGenerating => _status == QuickQuoteControllerStatus.generating;
  bool get isReady =>
      _status == QuickQuoteControllerStatus.ready ||
      _status == QuickQuoteControllerStatus.result;
  String? get errorMessage => _errorMessage;
  String? get mappingNotice => _mappingNotice;
  String? get generationError => _generationError;
  String? get budgetError => _budgetError;
  QuickQuoteResult? get result => _result;
  QuickQuoteRequest? get lastRequest => _lastRequest;
  String? get strengthBrand => _strengthBrand;
  String get premierPinSeriesPrefix => _premierPinSeriesPrefix;
  String get premierPlateSeriesPrefix => _premierPlateSeriesPrefix;

  UnmodifiableListView<String> get strengthBrands =>
      UnmodifiableListView(_strengthBrands);

  List<Product> cardioCandidates(QuickQuoteCardioRole role) =>
      UnmodifiableListView(_cardioCandidates[role] ?? const []);

  String? selectedCardioProductId(QuickQuoteCardioRole role) =>
      _selectedCardioProductIds[role];

  Product? selectedCardioProduct(QuickQuoteCardioRole role) {
    final selectedId = selectedCardioProductId(role);
    if (selectedId == null) return null;
    for (final product in cardioCandidates(role)) {
      if (product.id == selectedId) return product;
    }
    return null;
  }

  bool hasStrengthCandidate(
    QuickQuoteStrengthArea area,
    QuickQuoteLoadType loadType,
  ) =>
      _availabilityPool?.strengthPool(area, loadType).candidates.isNotEmpty ??
      false;

  bool hasMultifunctionCandidate(QuickQuoteMultifunctionRole role) =>
      _availabilityPool?.multifunctionCandidates[role]?.isNotEmpty ?? false;

  bool get hasDumbbellFullSetBundle =>
      _availabilityPool?.dumbbellFullSetBundles.isNotEmpty ?? false;

  bool get hasCompleteWeightPlateFamily =>
      _availabilityPool?.weightPlateBundles.isNotEmpty ?? false;

  Future<void> initialize() async {
    _status = QuickQuoteControllerStatus.loading;
    _errorMessage = null;
    _mappingNotice = null;
    _generationError = null;
    _budgetError = null;
    _result = null;
    _lastRequest = null;
    notifyListeners();

    try {
      if (productController.products.isEmpty) {
        await productController.loadProducts();
      }
      _activeProducts = productController.products
          .where((product) => product.isActive)
          .toList(growable: false);
      if (_activeProducts.isEmpty) {
        _setFatalError(
          'Product data unavailable. Load active products before creating a quick quote.',
        );
        return;
      }
    } catch (_) {
      _setFatalError(
        'Product data unavailable. Check the product catalog and try again.',
      );
      return;
    }

    try {
      try {
        _mappings = await mappingRepository.refreshMappings();
      } catch (_) {
        _mappings = await mappingRepository.getAllMappings();
        _mappingNotice =
            'Mapping refresh failed. Using the latest cached mappings.';
      }
      if (_mappings.isEmpty) {
        _setFatalError(
          'Quick Quote mappings are unavailable. Refresh mappings and try again.',
        );
        return;
      }
    } catch (_) {
      _setFatalError(
        'Quick Quote mappings are unavailable. Refresh mappings and try again.',
      );
      return;
    }

    try {
      _rebuildCatalog();
      if (_strengthBrands.isEmpty) {
        _setFatalError(
          'No mapped strength brands are available for the active product catalog.',
        );
        return;
      }
      _status = QuickQuoteControllerStatus.ready;
      notifyListeners();
    } catch (_) {
      _setFatalError(
        'Quick Quote setup could not be prepared from the current product data.',
      );
    }
  }

  void selectStrengthBrand(String brand) {
    if (!_strengthBrands.contains(brand) || brand == _strengthBrand) return;
    _strengthBrand = brand;
    _premierPinSeriesPrefix = 'APN';
    _premierPlateSeriesPrefix = 'APL';
    _selectionChanged();
  }

  void selectPremierPinSeries(String prefix) {
    if (!approvedPremierPinSeriesPrefixes.contains(prefix) ||
        prefix == _premierPinSeriesPrefix) {
      return;
    }
    _premierPinSeriesPrefix = prefix;
    _selectionChanged();
  }

  void selectPremierPlateSeries(String prefix) {
    if (!approvedPremierPlateSeriesPrefixes.contains(prefix) ||
        prefix == _premierPlateSeriesPrefix) {
      return;
    }
    _premierPlateSeriesPrefix = prefix;
    _selectionChanged();
  }

  void selectCardioProduct(QuickQuoteCardioRole role, String? productId) {
    if (productId != null &&
        !cardioCandidates(role).any((product) => product.id == productId)) {
      return;
    }
    if (_selectedCardioProductIds[role] == productId) return;
    _selectedCardioProductIds[role] = productId;
    _selectionChanged();
  }

  String? validateBudget(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Target equipment budget is required.';
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null || !parsed.isFinite) {
      return 'Enter a valid numeric amount.';
    }
    if (parsed <= 0) return 'Budget must be greater than zero.';
    return null;
  }

  Future<bool> generate(String rawBudget) async {
    final validationMessage = validateBudget(rawBudget);
    if (validationMessage != null) {
      _budgetError = validationMessage;
      _generationError = null;
      notifyListeners();
      return false;
    }

    _budgetError = null;
    _generationError = null;
    _result = null;
    _status = QuickQuoteControllerStatus.generating;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);

    try {
      final request = _buildRequest(
        double.parse(rawBudget.trim().replaceAll(',', '')),
      );
      final pool = _candidatePreparer.prepare(
        request: request,
        products: _activeProducts,
        mappings: _mappings,
      );
      final coverageError = _minimumCoverageError(pool);
      if (coverageError != null) {
        _generationError = coverageError;
        _status = QuickQuoteControllerStatus.ready;
        notifyListeners();
        return false;
      }

      _lastRequest = request;
      _result = _optimizer.optimize(request: request, candidatePool: pool);
      if (!_result!.hasCompleteMinimumBalancedCoverage) {
        _result = null;
        _generationError =
            'A balanced gym could not be generated from the current selections.';
        _status = QuickQuoteControllerStatus.ready;
        notifyListeners();
        return false;
      }
      _status = QuickQuoteControllerStatus.result;
      notifyListeners();
      return true;
    } catch (_) {
      _generationError =
          'The optimizer could not generate a gym. Review the selections and try again.';
      _status = QuickQuoteControllerStatus.ready;
      notifyListeners();
      return false;
    }
  }

  void _rebuildCatalog() {
    final productsById = {
      for (final product in _activeProducts) product.id: product,
    };
    final eligibleMappings = _mappings.where(
      (mapping) =>
          mapping.isEligible && productsById.containsKey(mapping.productId),
    );

    final brands = <String>{};
    final cardio = {
      for (final role in QuickQuoteCardioRole.values) role: <_RankedProduct>[],
    };
    for (final mapping in eligibleMappings) {
      final product = productsById[mapping.productId]!;
      if (mapping.section == QuickQuoteSection.strength) {
        brands.add(product.brand.trim());
      }
      if (mapping.section == QuickQuoteSection.cardio &&
          !_isHomeUseCardio(product)) {
        final role = QuickQuoteCardioRole.tryParse(mapping.roleKey);
        if (role != null) {
          cardio[role]!.add(_RankedProduct(product, mapping));
        }
      }
    }

    _strengthBrands = brands.where((brand) => brand.isNotEmpty).toList()
      ..sort((left, right) {
        if (isPremierBrand(left) != isPremierBrand(right)) {
          return isPremierBrand(left) ? -1 : 1;
        }
        return left.toLowerCase().compareTo(right.toLowerCase());
      });
    if (_strengthBrand == null || !_strengthBrands.contains(_strengthBrand)) {
      _strengthBrand = _strengthBrands.firstOrNull;
    }

    _cardioCandidates = {
      for (final entry in cardio.entries)
        entry.key: (entry.value..sort(_compareRankedProducts))
            .map((entry) => entry.product)
            .toList(growable: false),
    };
    for (final role in QuickQuoteCardioRole.values) {
      final candidates = _cardioCandidates[role]!;
      final previous = _selectedCardioProductIds[role];
      _selectedCardioProductIds[role] =
          candidates.any((product) => product.id == previous)
          ? previous
          : candidates.firstOrNull?.id;
    }
    _rebuildAvailability();
  }

  void _selectionChanged() {
    _generationError = null;
    _result = null;
    _lastRequest = null;
    _status = QuickQuoteControllerStatus.ready;
    _rebuildAvailability();
    notifyListeners();
  }

  void _rebuildAvailability() {
    if (_strengthBrand == null) {
      _availabilityPool = null;
      return;
    }
    _availabilityPool = _candidatePreparer.prepare(
      request: _buildRequest(1),
      products: _activeProducts,
      mappings: _mappings,
    );
  }

  QuickQuoteRequest _buildRequest(double targetBudget) {
    final brand = _strengthBrand;
    if (brand == null) throw StateError('No strength brand selected');
    return QuickQuoteRequest(
      targetBudget: targetBudget,
      strengthBrand: brand,
      premierPinSeriesPrefix: isPremierBrand(brand)
          ? _premierPinSeriesPrefix
          : null,
      premierPlateSeriesPrefix: isPremierBrand(brand)
          ? _premierPlateSeriesPrefix
          : null,
      cardioSelections: {
        for (final role in QuickQuoteCardioRole.values)
          if (_selectedCardioProductIds[role] != null)
            role: QuickQuoteCardioSelection(
              productId: _selectedCardioProductIds[role],
            ),
      },
      vatBudgetMode: QuickQuoteVatBudgetMode.includingVat,
    );
  }

  String? _minimumCoverageError(QuickQuoteCandidatePool pool) {
    final missingCardio = QuickQuoteCardioRole.values
        .where((role) => pool.cardioCandidates[role]!.isEmpty)
        .map(_cardioRoleLabel)
        .toList();
    if (missingCardio.isNotEmpty) {
      return 'Complete all five cardio selections. Missing: ${missingCardio.join(', ')}.';
    }

    final missingStrength = QuickQuoteStrengthArea.values
        .where((area) {
          return pool
                  .strengthPool(area, QuickQuoteLoadType.pinLoaded)
                  .candidates
                  .isEmpty &&
              pool
                  .strengthPool(area, QuickQuoteLoadType.plateLoaded)
                  .candidates
                  .isEmpty;
        })
        .map(_strengthAreaLabel)
        .toList();
    if (missingStrength.isNotEmpty) {
      return 'The selected brand and series have no candidates for: ${missingStrength.join(', ')}.';
    }
    if (pool.dumbbellFullSetBundles.isEmpty) {
      return 'A compatible dumbbell full-set bundle is unavailable.';
    }
    if (!pool.weightPlateBundles.any((bundle) => bundle.quantityEach == 8)) {
      return 'A complete weight plate family is unavailable.';
    }
    return null;
  }

  bool _isHomeUseCardio(Product product) {
    final searchable =
        '${product.category} ${product.name} ${product.description}'
            .toLowerCase();
    return searchable.contains('home use') || searchable.contains('home-use');
  }

  int _compareRankedProducts(_RankedProduct left, _RankedProduct right) {
    var result = left.mapping.selectionPriority.compareTo(
      right.mapping.selectionPriority,
    );
    if (result != 0) return result;
    result = left.product.sellingPrice.compareTo(right.product.sellingPrice);
    if (result != 0) return result;
    result = left.product.normalizedProductCode.compareTo(
      right.product.normalizedProductCode,
    );
    if (result != 0) return result;
    return left.product.id.compareTo(right.product.id);
  }

  void _setFatalError(String message) {
    _errorMessage = message;
    _status = QuickQuoteControllerStatus.error;
    notifyListeners();
  }
}

class _RankedProduct {
  const _RankedProduct(this.product, this.mapping);

  final Product product;
  final QuickQuoteProductMapping mapping;
}

String _cardioRoleLabel(QuickQuoteCardioRole role) => switch (role) {
  QuickQuoteCardioRole.treadmill => 'Treadmill',
  QuickQuoteCardioRole.crossTrainer => 'Cross Trainer',
  QuickQuoteCardioRole.recumbentBike => 'Recumbent Bike',
  QuickQuoteCardioRole.uprightBike => 'Upright Bike',
  QuickQuoteCardioRole.spinningBike => 'Spinning Bike',
};

String _strengthAreaLabel(QuickQuoteStrengthArea area) => switch (area) {
  QuickQuoteStrengthArea.chest => 'Chest',
  QuickQuoteStrengthArea.back => 'Back',
  QuickQuoteStrengthArea.shoulder => 'Shoulder',
  QuickQuoteStrengthArea.legs => 'Legs',
  QuickQuoteStrengthArea.arms => 'Arms',
  QuickQuoteStrengthArea.glutes => 'Glutes',
  QuickQuoteStrengthArea.core => 'Core',
};
