import 'package:flutter/foundation.dart';
import '../sync/sync_coordinator.dart';
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
import '../../features/authentication/data/supabase_auth_repository.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/products/application/bulk_import_service.dart';
import '../supabase/supabase_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../features/reservations/data/sembast_reservation_repository.dart';
import '../../features/reservations/data/supabase_reservation_repository.dart';
import '../../features/reservations/application/reservation_completion_service.dart';

class ServiceLocator {
  static ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  @visibleForTesting
  static void resetForTesting() {
    _instance = ServiceLocator._internal();
  }

  @visibleForTesting
  AuthRepository? mockAuthRepository;

  late final SembastAuthRepository _sembastAuthRepository =
      SembastAuthRepository();

  late final AuthRepository authRepository =
      mockAuthRepository ??
      SupabaseAuthRepository(
        supabaseService: supabaseService,
        localCache: _sembastAuthRepository,
      );

  late final AuthController authController = AuthController(authRepository);

  late final SembastQuotationRepository _sembastQuotationRepository =
      SembastQuotationRepository();

  late final QuotationRepository quotationRepository =
      SupabaseQuotationRepository(_sembastQuotationRepository, supabaseService);

  late final SembastProductRepository _sembastProductRepository =
      SembastProductRepository();

  @visibleForTesting
  ProductRepository? mockProductRepository;

  late final ProductRepository productRepository =
      mockProductRepository ??
      SupabaseProductRepository(
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

  late SyncCoordinator syncCoordinator = SyncCoordinator(
    client: supabaseService.client,
  );

  late final StockController stockController = StockController(stockRepository);

  late final ReservationCompletionService reservationCompletionService =
      ReservationCompletionService();

  late final StockOutByQuotationService stockOutByQuotationService =
      StockOutByQuotationService(quotationRepository: quotationRepository);

  @visibleForTesting
  SupabaseService? mockSupabaseService;

  late final SupabaseService supabaseService =
      mockSupabaseService ?? SupabaseService();

  late final BulkImportService bulkImportService = BulkImportService(
    productRepository,
    supabaseService,
  );

  late final SembastReservationRepository _sembastReservationRepository =
      SembastReservationRepository();

  late final ReservationRepository reservationRepository =
      SupabaseReservationRepository(
        localCache: _sembastReservationRepository,
        supabase: supabaseService,
      );

  Future<void> init() async {
    // Phase 7: Initialize Supabase connection.
    // Runs before repository inits so that remote data can be synced on startup.
    // A Supabase failure never blocks startup (fallback to local Sembast).
    try {
      await supabaseService.initialize();
    } catch (e) {
      debugPrint('Supabase init failed. Continuing offline. Error: $e');
    }

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

    try {
      await reservationRepository.syncFromServer();
    } catch (e) {
      debugPrint('Reservation sync failed. Error: $e');
    }

    try {
      // Initialize SyncCoordinator AFTER repositories and supabase
      await syncCoordinator.start();
    } catch (e) {
      debugPrint('SyncCoordinator start failed. Error: $e');
    }
  }
}
