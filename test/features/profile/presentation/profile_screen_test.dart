import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/profile/presentation/profile_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import '../../../features/authentication/fake_auth_repository.dart';

void main() {
  setUp(() async {
    ServiceLocator.resetForTesting();

    final dbName = 'test_profile_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    ServiceLocator().mockAuthRepository = FakeAuthRepository();
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
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.login: (context) =>
            const Scaffold(body: Text('Login Screen')),
      },
      initialRoute: AppRoutes.profile,
    );
  }

  testWidgets('Null-user safe state shows error and Go to Login button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());

    expect(find.text('Session not found.'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);

    await tester.tap(find.text('Go to Login'));
    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);
  });

  testWidgets('Current admin details display', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(
        username: 'anshad',
        password: 'anshad123',
        rememberMe: true,
      );
    });

    await tester.pumpWidget(buildTestableWidget());

    expect(find.text('Anshad'), findsOneWidget); // Name
    expect(find.text('Admin'), findsOneWidget); // Role
    expect(find.text('@anshad'), findsOneWidget);
    expect(find.text('ADMIN-001'), findsOneWidget);
  });

  testWidgets('Current salesperson details display', (
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

    expect(find.text('Ajmal'), findsOneWidget); // Name
    expect(find.text('Salesperson'), findsOneWidget); // Role
    expect(find.text('@ajmal'), findsOneWidget);
    expect(find.text('SALES-001'), findsOneWidget);
  });

  testWidgets('Cancel logout keeps user on Profile', (
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

    // Tap Logout button
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    // Dialog should be visible
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog should disappear, remain on Profile
    expect(find.text('Are you sure you want to log out?'), findsNothing);
    expect(find.text('ADMIN-001'), findsOneWidget); // still on profile
  });

  testWidgets('Confirm logout clears session and navigates to Login', (
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

    expect(ServiceLocator().authController.isAuthenticated, isTrue);

    // Tap Logout button
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    // Tap confirm Logout in dialog
    // We use runAsync to avoid the Sembast deadlock during put/delete
    await tester.runAsync(() async {
      await tester.tap(find.text('Logout').last); // the dialog button
    });

    await tester.pumpAndSettle();

    // Should navigate to Login
    expect(find.text('Login Screen'), findsOneWidget);

    // Session should be cleared
    expect(ServiceLocator().authController.isAuthenticated, isFalse);
    expect(ServiceLocator().authController.currentUser, isNull);
  });
}
