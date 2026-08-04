import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';

class DashboardSummary {
  final int totalProducts;
  final int activeProducts;
  final int inactiveProducts;
  final int totalQuotations;
  final int draftQuotations;
  final int approvedQuotations;
  final double retailStockValue;
  final int lowStockCount;

  const DashboardSummary({
    required this.totalProducts,
    required this.activeProducts,
    required this.inactiveProducts,
    required this.totalQuotations,
    required this.draftQuotations,
    required this.approvedQuotations,
    required this.retailStockValue,
    required this.lowStockCount,
  });
}

class ProductStockReport {
  final Product product;
  final int currentStock;
  final bool isLowStock;
  final bool isOutOfStock;

  const ProductStockReport({
    required this.product,
    required this.currentStock,
    required this.isLowStock,
    required this.isOutOfStock,
  });
}

class StockReports {
  final List<ProductStockReport> allStock;
  final List<ProductStockReport> lowStock;
  final List<ProductStockReport> outOfStock;
  final Map<String, int> movementVolumeByProduct; // absolute total in + out
  final List<Product> top10MostMoved;

  const StockReports({
    required this.allStock,
    required this.lowStock,
    required this.outOfStock,
    required this.movementVolumeByProduct,
    required this.top10MostMoved,
  });
}

class QuotationCustomerSummary {
  final String customerName;
  final int quotationCount;
  final double totalValue;

  const QuotationCustomerSummary({
    required this.customerName,
    required this.quotationCount,
    required this.totalValue,
  });
}

class QuotationReports {
  final int totalQuotations;
  final Map<QuotationStatus, int> statusBreakdown;
  final Map<String, int> monthlyQuotationCount; // YYYY-MM -> count
  final List<QuotationCustomerSummary> topCustomers;
  final double totalValue;

  const QuotationReports({
    required this.totalQuotations,
    required this.statusBreakdown,
    required this.monthlyQuotationCount,
    required this.topCustomers,
    required this.totalValue,
  });
}
