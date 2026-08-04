import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';
import 'package:eagleflow/features/quotations/application/quotation_calculator.dart';
import 'package:eagleflow/features/stock/domain/stock_repository.dart';

import 'reports_models.dart';

class ReportsService {
  final ProductRepository _productRepository;
  final StockRepository _stockRepository;
  final QuotationRepository _quotationRepository;

  ReportsService({
    ProductRepository? productRepository,
    StockRepository? stockRepository,
    QuotationRepository? quotationRepository,
  }) : _productRepository =
           productRepository ?? ServiceLocator().productRepository,
       _stockRepository = stockRepository ?? ServiceLocator().stockRepository,
       _quotationRepository =
           quotationRepository ?? ServiceLocator().quotationRepository;

  Future<DashboardSummary> getDashboardSummary() async {
    final products = await _productRepository.getAllProducts();
    final quotations = await _quotationRepository.getAllQuotations();
    final movements = await _stockRepository.getAllMovements();

    int activeProducts = 0;
    int inactiveProducts = 0;
    for (var p in products) {
      if (p.isActive) {
        activeProducts++;
      } else {
        inactiveProducts++;
      }
    }

    int draftQuotations = 0;
    int approvedQuotations = 0;
    for (var q in quotations) {
      if (q.status == QuotationStatus.draft) {
        draftQuotations++;
      } else if (q.status == QuotationStatus.approved) {
        approvedQuotations++;
      }
    }

    // Calculate current stock for each product
    final Map<String, int> stockMap = {};
    for (var p in products) {
      stockMap[p.id] = p.openingStock;
    }
    for (var m in movements) {
      final current = stockMap[m.productId] ?? 0;
      if (m.type.name == 'stockIn') {
        // StockMovementType.stockIn
        stockMap[m.productId] = current + m.quantity;
      } else {
        stockMap[m.productId] = current - m.quantity;
      }
    }

    double retailStockValue = 0.0;
    int lowStockCount = 0;
    for (var p in products) {
      final qty = stockMap[p.id] ?? 0;
      if (qty > 0) {
        retailStockValue += (qty * p.sellingPrice);
      }
      if (qty <= p.minStockLevel) {
        lowStockCount++;
      }
    }

    return DashboardSummary(
      totalProducts: products.length,
      activeProducts: activeProducts,
      inactiveProducts: inactiveProducts,
      totalQuotations: quotations.length,
      draftQuotations: draftQuotations,
      approvedQuotations: approvedQuotations,
      retailStockValue: retailStockValue,
      lowStockCount: lowStockCount,
    );
  }

  Future<StockReports> getStockReports() async {
    final products = await _productRepository.getAllProducts();
    final movements = await _stockRepository.getAllMovements();

    final Map<String, int> stockMap = {};
    final Map<String, int> movementVolume = {};

    for (var p in products) {
      stockMap[p.id] = p.openingStock;
      movementVolume[p.id] = 0;
    }

    for (var m in movements) {
      final current = stockMap[m.productId] ?? 0;
      if (m.type.name == 'stockIn') {
        stockMap[m.productId] = current + m.quantity;
      } else {
        stockMap[m.productId] = current - m.quantity;
      }

      final vol = movementVolume[m.productId] ?? 0;
      movementVolume[m.productId] = vol + m.quantity;
    }

    final allStock = <ProductStockReport>[];
    final lowStock = <ProductStockReport>[];
    final outOfStock = <ProductStockReport>[];

    for (var p in products) {
      final qty = stockMap[p.id] ?? 0;
      final report = ProductStockReport(
        product: p,
        currentStock: qty,
        isLowStock: qty <= p.minStockLevel && qty > 0,
        isOutOfStock: qty <= 0,
      );

      allStock.add(report);
      if (report.isOutOfStock) {
        outOfStock.add(report);
      } else if (qty <= p.minStockLevel) {
        lowStock.add(report);
      }
    }

    // Top 10 Most Moved Products
    final sortedVolume = movementVolume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top10MostMoved = <Product>[];
    for (var i = 0; i < sortedVolume.length && i < 10; i++) {
      if (sortedVolume[i].value > 0) {
        final prod = products.firstWhere(
          (p) => p.id == sortedVolume[i].key,
          orElse: () => products.first,
        );
        if (prod.id == sortedVolume[i].key) {
          // check valid match
          top10MostMoved.add(prod);
        }
      }
    }

    return StockReports(
      allStock: allStock,
      lowStock: lowStock,
      outOfStock: outOfStock,
      movementVolumeByProduct: movementVolume,
      top10MostMoved: top10MostMoved,
    );
  }

  Future<QuotationReports> getQuotationReports() async {
    final quotations = await _quotationRepository.getAllQuotations();

    final statusBreakdown = <QuotationStatus, int>{};
    final monthlyQuotationCount = <String, int>{};
    final Map<String, QuotationCustomerSummary> customerMap = {};
    double totalValue = 0.0;

    for (var q in quotations) {
      // Status breakdown
      statusBreakdown[q.status] = (statusBreakdown[q.status] ?? 0) + 1;

      // Monthly Count
      final monthStr =
          '${q.createdDate.year}-${q.createdDate.month.toString().padLeft(2, '0')}';
      monthlyQuotationCount[monthStr] =
          (monthlyQuotationCount[monthStr] ?? 0) + 1;

      // Customer
      final custName = q.customerInfo.name.trim();
      final double subTotal = QuotationCalculator.calculateSubtotal(
        q.lineItems,
      );
      final double grandTotal = QuotationCalculator.calculateGrandTotal(
        subTotal,
        q.charges,
      );
      if (custName.isNotEmpty) {
        final existing = customerMap[custName];
        if (existing == null) {
          customerMap[custName] = QuotationCustomerSummary(
            customerName: custName,
            quotationCount: 1,
            totalValue: grandTotal,
          );
        } else {
          customerMap[custName] = QuotationCustomerSummary(
            customerName: custName,
            quotationCount: existing.quotationCount + 1,
            totalValue: existing.totalValue + grandTotal,
          );
        }
      }

      totalValue += grandTotal;
    }

    final topCustomers = customerMap.values.toList()
      ..sort((a, b) => b.totalValue.compareTo(a.totalValue));

    return QuotationReports(
      totalQuotations: quotations.length,
      statusBreakdown: statusBreakdown,
      monthlyQuotationCount: monthlyQuotationCount,
      topCustomers: topCustomers,
      totalValue: totalValue,
    );
  }
}
