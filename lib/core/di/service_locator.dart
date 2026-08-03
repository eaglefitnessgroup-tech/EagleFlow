import 'package:flutter/foundation.dart';
import '../../features/quotations/data/quotation_repository.dart';
import '../../features/quotations/data/sembast_quotation_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/products/data/sembast_product_repository.dart';
import '../../features/products/application/product_master_controller.dart';
import '../../features/stock/domain/stock_repository.dart';
import '../../features/stock/data/sembast_stock_repository.dart';
import '../../features/stock/application/stock_controller.dart';
import '../../features/stock/application/stock_out_by_quotation_service.dart';
import '../../features/authentication/domain/auth_repository.dart';
import '../../features/authentication/data/sembast_auth_repository.dart';
import '../../features/authentication/application/auth_controller.dart';

class ServiceLocator {
  static ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  @visibleForTesting
  static void resetForTesting() {
    _instance = ServiceLocator._internal();
  }

  late final AuthRepository authRepository = SembastAuthRepository();

  late final AuthController authController = AuthController(authRepository);

  late final QuotationRepository quotationRepository =
      SembastQuotationRepository();

  late final ProductRepository productRepository = SembastProductRepository();

  late final ProductMasterController productMasterController =
      ProductMasterController(productRepository);

  late final StockRepository stockRepository = SembastStockRepository();

  late final StockController stockController = StockController(stockRepository);

  late final StockOutByQuotationService stockOutByQuotationService =
      StockOutByQuotationService(quotationRepository: quotationRepository);

  Future<void> init() async {
    try {
      await authController.initialize();
    } catch (e) {
      // Safely ignore failures to prevent blocking app startup
    }

    await productRepository.init();
    await productMasterController.loadProducts();
  }
}
