import '../../features/quotations/data/quotation_repository.dart';
import '../../features/quotations/data/sembast_quotation_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/products/data/sembast_product_repository.dart';
import '../../features/products/application/product_master_controller.dart';
import '../../features/stock/domain/stock_repository.dart';
import '../../features/stock/data/sembast_stock_repository.dart';
import '../../features/stock/application/stock_controller.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final QuotationRepository quotationRepository =
      SembastQuotationRepository();

  late final ProductRepository productRepository = SembastProductRepository();

  late final ProductMasterController productMasterController =
      ProductMasterController(productRepository);

  late final StockRepository stockRepository = SembastStockRepository();

  late final StockController stockController = StockController(stockRepository);

  Future<void> init() async {
    await productRepository.init();
    await productMasterController.loadProducts();
  }
}
