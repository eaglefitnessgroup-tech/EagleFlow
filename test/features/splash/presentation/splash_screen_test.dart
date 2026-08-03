import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/splash/presentation/splash_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/app/routes/app_routes.dart';

void main() {
  setUp(() async {
    // Reset any previous state first
    ServiceLocator.resetForTesting();
    
    final dbName = 'test_splash_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);
    
    // Ensure fresh init
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
        '/': (context) => const SplashScreen(),
        AppRoutes.login: (context) =>
            const Scaffold(body: Text('Login Screen')),
        AppRoutes.dashboard: (context) =>
            const Scaffold(body: Text('Dashboard Screen')),
      },
      initialRoute: '/',
    );
  }

  testWidgets('No remembered session navigates to Login after delay', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    
    // Initial state should be splash screen
    expect(find.byType(SplashScreen), findsOneWidget);
    
    // Fast-forward past the splash screen delay (2200ms)
    await tester.pumpAndSettle();
    
    // Should navigate to login
    expect(find.text('Login Screen'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('Remembered authenticated user navigates to Dashboard after delay', (WidgetTester tester) async {
    // Simulate active session
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(username: 'admin', password: 'admin123', rememberMe: true);
    });
    
    await tester.pumpWidget(buildTestableWidget());
    
    // Initial state should be splash screen
    expect(find.byType(SplashScreen), findsOneWidget);
    
    // Fast-forward past the splash screen delay (2200ms)
    await tester.pumpAndSettle();
    
    // Should navigate to dashboard
    expect(find.text('Dashboard Screen'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
