import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/domain/quotation_reservation.dart';
import 'package:eagleflow/core/reports/reports_service.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/stock/domain/stock_movement.dart';
import 'package:eagleflow/features/stock/domain/stock_repository.dart';

class MockProductRepository implements ProductRepository {
  List<Product> products = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<Product>> getAllProducts() async => products;

  @override
  Future<Product?> getProductById(String id) async =>
      products.firstWhere((p) => p.id == id);

  @override
  Future<Product> getProductWithImage(Product product) async => product;

  @override
  Future<Product> addProduct(Product product) async => product;

  @override
  Future<void> addProducts(List<Product> products) async {}

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<bool> hasQuotationReferences(String productId) async => false;

  @override
  Future<bool> isProductCodeUnique(String code, {String? excludeId}) async =>
      true;

  @override
  Future<void> toggleProductStatus(String id, bool isActive) async {}
}

class MockStockRepository implements StockRepository {
  List<StockMovement> movements = [];

  @override
  Future<StockMovement> addMovement(StockMovement movement) async => movement;

  @override
  Future<List<StockMovement>> getMovementsForProduct(String productId) async =>
      movements.where((m) => m.productId == productId).toList();

  @override
  Future<List<StockMovement>> getAllMovements() async => movements;

  @override
  Future<void> deleteMovement(String movementId) async {}

  @override
  Future<int> calculateCurrentStock({
    required String productId,
    required int openingStock,
  }) async {
    return 0; // Not used by reports directly
  }
}

class MockQuotationRepository implements QuotationRepository {
  List<Quotation> quotations = [];

  @override
  Future<List<Quotation>> getAllQuotations() async => quotations;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async => quotation;

  @override
  Future<void> deleteQuotation(String id) async {}

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) async =>
      sourceQuotation;

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async =>
      quotation;

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) async => null;

  @override
  Future<ReservationAggregation> getReservationsForProduct(String productId) async => 
      const ReservationAggregation(reservedQty: 0, reservations: []);
}

void main() {
  late MockProductRepository mockProductRepo;
  late MockStockRepository mockStockRepo;
  late MockQuotationRepository mockQuotationRepo;
  late ReportsService reportsService;

  setUp(() {
    mockProductRepo = MockProductRepository();
    mockStockRepo = MockStockRepository();
    mockQuotationRepo = MockQuotationRepository();
    reportsService = ReportsService(
      productRepository: mockProductRepo,
      stockRepository: mockStockRepo,
      quotationRepository: mockQuotationRepo,
    );
  });

  Product createProduct(String id, double price, int minStock, bool isActive) {
    return Product(
      id: id,
      productCode: 'SKU-$id',
      name: 'Product $id',
      category: 'Cat',
      brand: 'Brand',
      sellingPrice: price,
      minStockLevel: minStock,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  StockMovement createMovement(
    String productId,
    StockMovementType type,
    int qty,
  ) {
    return StockMovement(
      id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      type: type,
      quantity: qty,
      reference: 'REF',
      movementDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  Quotation createQuotation(
    String id,
    QuotationStatus status,
    String customerName,
    double total,
    DateTime date,
  ) {
    // A dummy item that gives the total value.
    final item = QuotationLineItem(
      id: 'item1',
      productId: 'p1',
      name: 'Dummy',
      brand: 'Dummy',
      quantity: 1,
      unitPrice: total,
    );

    return Quotation(
      id: id,
      quotationNumber: 'QT-$id',
      customerInfo: CustomerInfo(
        name: customerName,
        phone: '',
        email: '',
        company: '',
      ),
      salespersonId: 'sp1',
      createdDate: date,
      modifiedDate: date,
      validUntil: date,
      expectedDelivery: date,
      status: status,
      lineItems: [item],
      charges: const QuotationCharges(),
    );
  }

  test('Empty database handles cleanly', () async {
    final dash = await reportsService.getDashboardSummary();
    expect(dash.totalProducts, 0);
    expect(dash.retailStockValue, 0.0);

    final stock = await reportsService.getStockReports();
    expect(stock.allStock.isEmpty, true);

    final quotes = await reportsService.getQuotationReports();
    expect(quotes.totalQuotations, 0);
  });

  test('Dashboard summary calculates correctly', () async {
    mockProductRepo.products = [
      createProduct('1', 10.0, 5, true),
      createProduct('2', 20.0, 2, false),
    ];
    mockStockRepo.movements = [
      createMovement('1', StockMovementType.stockIn, 10),
      createMovement('2', StockMovementType.stockIn, 1), // Low stock
    ];
    mockQuotationRepo.quotations = [
      createQuotation(
        'q1',
        QuotationStatus.draft,
        'Cust A',
        100,
        DateTime.now(),
      ),
      createQuotation(
        'q2',
        QuotationStatus.approved,
        'Cust B',
        200,
        DateTime.now(),
      ),
    ];

    final dash = await reportsService.getDashboardSummary();

    expect(dash.totalProducts, 2);
    expect(dash.activeProducts, 1);
    expect(dash.inactiveProducts, 1);
    expect(dash.totalQuotations, 2);
    expect(dash.draftQuotations, 1);
    expect(dash.approvedQuotations, 1);
    expect(dash.lowStockCount, 1); // Product 2 has 1 stock, min is 2
    expect(dash.retailStockValue, (10 * 10.0) + (1 * 20.0));
  });

  test(
    'Stock reports accurately identify low and out-of-stock items',
    () async {
      mockProductRepo.products = [
        createProduct('1', 10.0, 5, true),
        createProduct('2', 10.0, 5, true),
        createProduct('3', 10.0, 5, true),
      ];

      mockStockRepo.movements = [
        createMovement('1', StockMovementType.stockIn, 10), // Healthy: 10
        createMovement('2', StockMovementType.stockIn, 3), // Low stock: 3 <= 5
        createMovement('3', StockMovementType.stockIn, 10),
        createMovement(
          '3',
          StockMovementType.stockOut,
          10,
        ), // Out of stock: 0 <= 0
      ];

      final stock = await reportsService.getStockReports();

      expect(stock.lowStock.length, 1);
      expect(stock.lowStock.first.product.id, '2');

      expect(stock.outOfStock.length, 1);
      expect(stock.outOfStock.first.product.id, '3');

      expect(stock.top10MostMoved.first.id, '3'); // Volume 20
    },
  );

  test('Quotation reports aggregate monthly and by customer', () async {
    final date1 = DateTime(2026, 1, 15);
    final date2 = DateTime(2026, 1, 20);
    final date3 = DateTime(2026, 2, 10);

    mockQuotationRepo.quotations = [
      createQuotation('q1', QuotationStatus.draft, 'Cust A', 100, date1),
      createQuotation('q2', QuotationStatus.approved, 'Cust A', 200, date2),
      createQuotation('q3', QuotationStatus.sent, 'Cust B', 500, date3),
    ];

    final reports = await reportsService.getQuotationReports();

    expect(reports.totalQuotations, 3);
    expect(reports.totalValue, 840.0);
    expect(reports.statusBreakdown[QuotationStatus.draft], 1);
    expect(reports.statusBreakdown[QuotationStatus.approved], 1);

    expect(reports.monthlyQuotationCount['2026-01'], 2);
    expect(reports.monthlyQuotationCount['2026-02'], 1);

    expect(reports.topCustomers.length, 2);
    expect(reports.topCustomers.first.customerName, 'Cust B'); // 500
    expect(reports.topCustomers.last.customerName, 'Cust A'); // 300
  });

  test('Large dataset performance is acceptable (under 1 second)', () async {
    for (int i = 0; i < 5000; i++) {
      mockProductRepo.products.add(createProduct('p$i', 10.0, 5, true));
    }
    for (int i = 0; i < 15000; i++) {
      mockStockRepo.movements.add(
        createMovement('p${i % 5000}', StockMovementType.stockIn, 1),
      );
    }
    for (int i = 0; i < 2000; i++) {
      mockQuotationRepo.quotations.add(
        createQuotation(
          'q$i',
          QuotationStatus.approved,
          'Customer ${i % 100}',
          100,
          DateTime.now(),
        ),
      );
    }

    final stopwatch = Stopwatch()..start();

    await reportsService.getDashboardSummary();
    await reportsService.getStockReports();
    await reportsService.getQuotationReports();

    stopwatch.stop();
    // In memory this should be highly performant, < 1000ms
    expect(stopwatch.elapsedMilliseconds < 1000, true);
  });
}
