import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/app/routes/app_routes.dart';

void main() {
  setUp(() async {
    ServiceLocator.resetForTesting();

    final dbName = 'test_dashboard_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    await ServiceLocator().init();
    await ServiceLocator().authController.logout();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      routes: {
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        AppRoutes.products: (context) =>
            const Scaffold(body: Text('Products Screen')),
        AppRoutes.previousQuotations: (context) =>
            const Scaffold(body: Text('Quotations Screen')),
        AppRoutes.stockManagement: (context) =>
            const Scaffold(body: Text('Stock Screen')),
        AppRoutes.profile: (context) =>
            const Scaffold(body: Text('Profile Screen')),
        AppRoutes.createQuotation: (context) =>
            const Scaffold(body: Text('Create Quotation Screen')),
      },
      initialRoute: AppRoutes.dashboard,
    );
  }

  testWidgets('Admin name appears and Stock Management card is visible', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(
        username: 'anshad',
        password: 'anshad123',
        rememberMe: true,
      );
    });

    await tester.pumpWidget(buildTestableWidget());

    // Greeting
    expect(find.text('Anshad'), findsOneWidget);

    // Admin specific card
    expect(find.textContaining('Stock\nManagement'), findsOneWidget);

    // Shared actions (Products appears in Grid and BottomNav so findsWidgets is correct)
    expect(find.text('Products'), findsWidgets);
    expect(find.textContaining('Previous\nQuotations'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
  });

  testWidgets('Salesperson name appears and Stock Management card is hidden', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(
        username: 'ajmal',
        password: 'ajmal123',
        rememberMe: true,
      );
    });

    await tester.pumpWidget(buildTestableWidget());

    // Greeting
    expect(find.text('Ajmal'), findsOneWidget);

    // Admin specific card
    expect(find.textContaining('Stock\nManagement'), findsNothing);

    // Shared actions
    expect(find.text('Products'), findsWidgets);
    expect(find.textContaining('Previous\nQuotations'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
  });

  testWidgets('Null-user fallback does not crash and shows User', (
    WidgetTester tester,
  ) async {
    // Ensuring no user is logged in
    expect(ServiceLocator().authController.currentUser, isNull);

    await tester.pumpWidget(buildTestableWidget());

    // Greeting
    expect(find.text('User'), findsOneWidget);

    // Admin specific card should be hidden
    expect(find.textContaining('Stock\nManagement'), findsNothing);

    // Shared actions
    expect(find.text('Products'), findsWidgets);
    expect(find.textContaining('Previous\nQuotations'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
  });
}
