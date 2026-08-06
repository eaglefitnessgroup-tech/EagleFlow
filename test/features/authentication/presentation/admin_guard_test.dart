import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/stock/presentation/stock_management_screen.dart';
import 'package:eagleflow/features/stock/presentation/stock_in_screen.dart';
import 'package:eagleflow/features/stock/presentation/stock_out_screen.dart';
import 'package:eagleflow/features/stock/presentation/stock_out_by_quotation_screen.dart';
import 'package:eagleflow/features/products/presentation/add_edit_product_screen.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Create a fake admin user without touching the DB.
AppUser _fakeAdmin() => AppUser(
  id: 'ADMIN-001',
  name: 'Admin',
  username: 'admin',
  passwordHash: 'x',
  role: UserRole.admin,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Create a fake salesperson user without touching the DB.
AppUser _fakeSales() => AppUser(
  id: 'sales123',
  name: 'Test Sales',
  username: 'sales',
  passwordHash: 'hash',
  role: UserRole.sales,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Test setup
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    ServiceLocator.resetForTesting();
    // Provide an in-memory DB so all repository constructors work.
    final db = await databaseFactoryMemory.openDatabase(
      'guard_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(db);

    // Initialize only the auth controller so that SembastAuthRepository's
    // _initDefaultUsers() async write completes (draining its Sembast timer)
    // before any test pump runs.  We skip productRepository.init() entirely
    // to avoid the slow sample-data seeding.
    await ServiceLocator().authController.initialize();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  /// Sets the auth state directly on the shared AuthController.
  void setAuthState(AppUser? user) {
    ServiceLocator().authController.setCurrentUserForTesting(user);
  }

  /// Minimal MaterialApp with only the routes AdminGuard needs to navigate to.
  Widget buildTestApp(Widget home) {
    return MaterialApp(
      home: home,
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('MockLoginScreen')),
        AppRoutes.dashboard: (_) =>
            const Scaffold(body: Text('MockDashboardScreen')),
      },
    );
  }

  /// Pumps widget then settles all animations (navigation, snackbar fade-in).
  /// Safe here because our mock routes (plain Scaffold+Text) have no infinite
  /// animations, so pumpAndSettle terminates quickly.
  Future<void> pumpAndCheck(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(buildTestApp(home));
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  group('AdminGuard', () {
    // -- Unauthenticated ----------------------------------------------------

    testWidgets('unauthenticated → redirected to Login', (tester) async {
      setAuthState(null); // not logged in

      await pumpAndCheck(tester, const StockManagementScreen());

      expect(find.text('MockLoginScreen'), findsOneWidget);
      expect(find.text('Stock Management'), findsNothing);
    });

    // -- Salesperson (non-admin) --------------------------------------------

    testWidgets('salesperson → StockManagementScreen → Dashboard + snackbar', (
      tester,
    ) async {
      setAuthState(_fakeSales());

      await pumpAndCheck(tester, const StockManagementScreen());

      expect(find.text('MockDashboardScreen'), findsOneWidget);
      expect(find.text('Admin access required.'), findsOneWidget);
      expect(find.text('Stock Management'), findsNothing);
    });

    testWidgets('salesperson → StockInScreen → Dashboard + snackbar', (
      tester,
    ) async {
      setAuthState(_fakeSales());

      await pumpAndCheck(tester, const StockInScreen());

      expect(find.text('MockDashboardScreen'), findsOneWidget);
      expect(find.text('Admin access required.'), findsOneWidget);
    });

    testWidgets('salesperson → StockOutScreen → Dashboard + snackbar', (
      tester,
    ) async {
      setAuthState(_fakeSales());

      await pumpAndCheck(tester, const StockOutScreen());

      expect(find.text('MockDashboardScreen'), findsOneWidget);
      expect(find.text('Admin access required.'), findsOneWidget);
    });

    testWidgets(
      'salesperson → StockOutByQuotationScreen → Dashboard + snackbar',
      (tester) async {
        setAuthState(_fakeSales());

        await pumpAndCheck(tester, const StockOutByQuotationScreen());

        expect(find.text('MockDashboardScreen'), findsOneWidget);
        expect(find.text('Admin access required.'), findsOneWidget);
      },
    );

    testWidgets('salesperson → AddEditProductScreen → Dashboard + snackbar', (
      tester,
    ) async {
      setAuthState(_fakeSales());

      await pumpAndCheck(tester, const AddEditProductScreen());

      expect(find.text('MockDashboardScreen'), findsOneWidget);
      expect(find.text('Admin access required.'), findsOneWidget);
    });

    // -- Admin --------------------------------------------------------------

    testWidgets('admin → StockManagementScreen renders normally', (
      tester,
    ) async {
      setAuthState(_fakeAdmin());

      await pumpAndCheck(tester, const StockManagementScreen());

      expect(find.text('Stock Management'), findsWidgets);
      expect(find.text('MockLoginScreen'), findsNothing);
      expect(find.text('MockDashboardScreen'), findsNothing);
      expect(find.text('Admin access required.'), findsNothing);
    });

    testWidgets('admin → StockInScreen renders normally', (tester) async {
      setAuthState(_fakeAdmin());

      await pumpAndCheck(tester, const StockInScreen());

      expect(find.text('Stock In'), findsOneWidget);
      expect(find.text('Admin access required.'), findsNothing);
    });

    testWidgets('admin → StockOutScreen renders normally', (tester) async {
      setAuthState(_fakeAdmin());

      await pumpAndCheck(tester, const StockOutScreen());

      expect(find.text('Stock Out'), findsOneWidget);
      expect(find.text('Admin access required.'), findsNothing);
    });

    testWidgets('admin → AddEditProductScreen renders normally', (
      tester,
    ) async {
      setAuthState(_fakeAdmin());

      await pumpAndCheck(tester, const AddEditProductScreen());

      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Admin access required.'), findsNothing);
    });
  });
}
