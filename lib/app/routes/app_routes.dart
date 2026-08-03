import 'package:flutter/material.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/product_details_screen.dart';
import '../../features/quotations/presentation/create_quotation_screen.dart';
import '../../features/quotations/presentation/quotation_preview_screen.dart';
import '../../features/quotations/presentation/previous_quotations_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/stock/presentation/stock_management_screen.dart';
import '../../features/stock/presentation/stock_in_screen.dart';
import '../../features/stock/presentation/stock_out_screen.dart';
import '../../features/stock/presentation/stock_out_by_quotation_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String productDetails = '/product-details';
  static const String createQuotation = '/create-quotation';
  static const String quotationPreview = '/quotation-preview';
  static const String previousQuotations = '/previous-quotations';
  static const String profile = '/profile';
  static const String stockManagement = '/stock-management';
  static const String stockIn = '/stock-in';
  static const String stockOut = '/stock-out';
  static const String stockOutByQuotation = '/stock-out-by-quotation';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      dashboard: (context) => const DashboardScreen(),
      products: (context) => const ProductsScreen(),
      productDetails: (context) => const ProductDetailsScreen(),
      createQuotation: (context) => const CreateQuotationScreen(),
      quotationPreview: (context) => const QuotationPreviewScreen(),
      previousQuotations: (context) => const PreviousQuotationsScreen(),
      profile: (context) => const ProfileScreen(),
      stockManagement: (context) => const StockManagementScreen(),
      stockIn: (context) => const StockInScreen(),
      stockOut: (context) => const StockOutScreen(),
      stockOutByQuotation: (context) => const StockOutByQuotationScreen(),
    };
  }
}
