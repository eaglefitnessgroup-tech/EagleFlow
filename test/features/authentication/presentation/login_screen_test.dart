import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/authentication/presentation/login_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/app/routes/app_routes.dart';

void main() {
  setUp(() async {
    // Reset any previous state first
    ServiceLocator.resetForTesting();

    // Setup in-memory DB so SembastAuthRepository works correctly
    final dbName = 'test_login_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    // Initialize the real ServiceLocator
    await ServiceLocator().init();

    // Ensure we are logged out before each test
    await ServiceLocator().authController.logout();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      routes: {
        '/': (context) => const LoginScreen(),
        AppRoutes.dashboard: (context) =>
            const Scaffold(body: Text('Dashboard')),
      },
      initialRoute: '/',
    );
  }

  testWidgets('Required-field validation', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());

    // Tap login button without entering anything
    await tester.tap(find.text('Secure Login'));
    await tester.pump();

    // Expect validation errors
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Invalid credentials error', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());

    // Enter wrong credentials
    await tester.enterText(find.byType(TextFormField).first, 'wronguser');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpass');

    // Tap login
    await tester.tap(find.text('Secure Login'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 50)); // Wait for repo
    await tester.pumpAndSettle(); // Finish animation

    // Expect error message
    expect(find.text('Invalid username or password.'), findsOneWidget);

    // Expect fields to retain their values
    expect(find.text('wronguser'), findsOneWidget);
  });

  testWidgets('Successful admin login navigation', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());

    // Enter admin credentials (based on default seed)
    await tester.enterText(find.byType(TextFormField).first, 'anshad');
    await tester.enterText(find.byType(TextFormField).last, 'anshad123');

    // Tap login
    await tester.tap(find.text('Secure Login'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Expect navigation to Dashboard
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Duplicate-submit/loading protection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());

    await tester.enterText(find.byType(TextFormField).first, 'anshad');
    await tester.enterText(find.byType(TextFormField).last, 'anshad123');

    // Tap login
    await tester.tap(find.text('Secure Login'));
    await tester.pump(); // Start load

    // Button text should be gone, replaced by progress indicator
    expect(find.text('Secure Login'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Check if the button is disabled
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });
}
