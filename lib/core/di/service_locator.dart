import 'package:flutter/foundation.dart';
import '../../features/quotations/data/quotation_repository.dart';
import '../../features/quotations/data/sembast_quotation_repository.dart';
import '../../features/quotations/data/supabase_quotation_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/products/data/sembast_product_repository.dart';
import '../../features/products/data/supabase_product_repository.dart';
import '../../features/products/application/product_master_controller.dart';
import '../../features/stock/domain/stock_repository.dart';
import '../../features/stock/data/sembast_stock_repository.dart';
import '../../features/stock/data/supabase_stock_repository.dart';
import '../../features/stock/application/stock_controller.dart';
import '../../features/stock/application/stock_out_by_quotation_service.dart';
import '../../features/authentication/domain/auth_repository.dart';
import '../../features/authentication/data/sembast_auth_repository.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../supabase/supabase_service.dart';

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

  late final SembastQuotationRepository _sembastQuotationRepository =
      SembastQuotationRepository();

  late final QuotationRepository quotationRepository =
      SupabaseQuotationRepository(_sembastQuotationRepository, supabaseService);

  late final SembastProductRepository _sembastProductRepository =
      SembastProductRepository();

  late final ProductRepository productRepository = SupabaseProductRepository(
    localCache: _sembastProductRepository,
    supabase: supabaseService,
  );

  late final ProductMasterController productMasterController =
      ProductMasterController(productRepository);

  late final SembastStockRepository _sembastStockRepository =
      SembastStockRepository();

  late final StockRepository stockRepository = SupabaseStockRepository(
    _sembastStockRepository,
    supabaseService,
  );

  late final StockController stockController = StockController(stockRepository);

  late final StockOutByQuotationService stockOutByQuotationService =
      StockOutByQuotationService(quotationRepository: quotationRepository);

  late final SupabaseService supabaseService = SupabaseService();

  Future<void> init() async {
    try {
      await authController.initialize();
    } catch (e) {
      // Safely ignore failures to prevent blocking app startup
    }

    await productRepository.init();
    await productMasterController.loadProducts();

    if (stockRepository is SupabaseStockRepository) {
      await (stockRepository as SupabaseStockRepository).init();
    }

    if (quotationRepository is SupabaseQuotationRepository) {
      await (quotationRepository as SupabaseQuotationRepository).init();
    }

    // Phase 7: Initialize Supabase connection.
    // Runs after Sembast is ready. A Supabase failure never blocks startup.
    try {
      await supabaseService.initialize();
    } catch (e) {
      // Supabase is optional at this stage — app operates in local-only mode.
    }
  }
}
