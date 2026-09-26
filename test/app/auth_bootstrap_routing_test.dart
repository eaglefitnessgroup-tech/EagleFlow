import 'dart:async';

import 'package:eagleflow/app/app.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';
import 'package:eagleflow/features/authentication/presentation/login_screen.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/features/splash/presentation/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late _DelayedAuthRepository authRepository;

  setUp(() async {
    ServiceLocator.resetForTesting();

    final database = await databaseFactoryMemory.openDatabase(
      'auth_bootstrap_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);

    authRepository = _DelayedAuthRepository();
    ServiceLocator().mockAuthRepository = authRepository;
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  void useDashboardDeepLink(WidgetTester tester) {
    tester.platformDispatcher.defaultRouteNameTestValue = AppRoutes.dashboard;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  testWidgets(
    'unauthenticated dashboard deep link shows Login without building Dashboard',
    (WidgetTester tester) async {
      useDashboardDeepLink(tester);

      await tester.pumpWidget(const EagleFlowApp());
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);

      unawaited(ServiceLocator().authController.initialize());
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);

      authRepository.completeRestore(null);
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );

  testWidgets('delayed auth restore never builds Dashboard while unresolved', (
    WidgetTester tester,
  ) async {
    useDashboardDeepLink(tester);

    unawaited(ServiceLocator().authController.initialize());
    await tester.pumpWidget(const EagleFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);

    authRepository.completeRestore(_authenticatedUser());
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets(
    'authenticated dashboard deep link remains on Dashboard after splash delay',
    (WidgetTester tester) async {
      useDashboardDeepLink(tester);

      await tester.runAsync(() async {
        authRepository.completeRestore(_authenticatedUser());
        await ServiceLocator().authController.initialize();
      });
      await tester.pumpWidget(const EagleFlowApp());
      await tester.pump();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );
}

AppUser _authenticatedUser() {
  final now = DateTime(2026, 9, 17);
  return AppUser(
    id: 'SALES-001',
    name: 'Ajmal',
    username: 'ajmal',
    passwordHash: '',
    role: UserRole.sales,
    createdAt: now,
    updatedAt: now,
  );
}

class _DelayedAuthRepository implements AuthRepository {
  final Completer<AppUser?> _restoreCompleter = Completer<AppUser?>.sync();

  void completeRestore(AppUser? user) {
    _restoreCompleter.complete(user);
  }

  @override
  Future<AppUser?> getCurrentUser() => _restoreCompleter.future;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async => AuthResult.failure('Not used in this test.');

  @override
  Future<void> logout() async {}

  @override
  Future<List<AppUser>> getUsers() async => [];

  @override
  Future<bool> hasRememberedSession() async => false;

  @override
  Future<void> clearRememberedSession() async {}
}
