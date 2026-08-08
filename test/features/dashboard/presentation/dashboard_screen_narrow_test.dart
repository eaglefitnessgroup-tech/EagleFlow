import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import '../../../features/authentication/fake_auth_repository.dart';

void main() {
  setUp(() async {
    ServiceLocator.resetForTesting();

    final dbName = 'test_dashboard_narrow_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    ServiceLocator().mockAuthRepository = FakeAuthRepository();
    await ServiceLocator().init();
    
    // Login as admin to show all cards
    await ServiceLocator().authController.login(
      username: 'anshad',
      password: 'anshad123',
      rememberMe: true,
    );
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      routes: {
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        AppRoutes.products: (context) => const Scaffold(body: Text('Products Screen')),
        AppRoutes.previousQuotations: (context) => const Scaffold(body: Text('Quotations Screen')),
        AppRoutes.stockManagement: (context) => const Scaffold(body: Text('Stock Screen')),
        AppRoutes.profile: (context) => const Scaffold(body: Text('Profile Screen')),
        AppRoutes.createQuotation: (context) => const Scaffold(body: Text('Create Quotation Screen')),
        AppRoutes.itemReservation: (context) => const Scaffold(body: Text('Item Reservation Screen')),
      },
      initialRoute: AppRoutes.dashboard,
    );
  }

  group('DashboardScreen Responsive Layout Tests', () {
    testWidgets('Does not overflow on narrow mobile screen (360x800)', (WidgetTester tester) async {
      // Set narrow physical size
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow occurs
      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Dashboard layout should not overflow at 360x800');
      
      // Verify the grid cards rendered correctly
      expect(find.text('Products'), findsWidgets);
      expect(find.textContaining('Previous\nQuotations'), findsOneWidget);
      expect(find.text('Item Reservation'), findsOneWidget);
    });
  });
}
