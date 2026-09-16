import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/app/app.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/authentication/presentation/login_screen.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sembast/sembast_memory.dart';
import 'features/authentication/fake_auth_repository.dart';

void main() {
  setUpAll(() async {
    ServiceLocator.resetForTesting();
    final dbName = 'test_main_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);
    ServiceLocator().mockAuthRepository = FakeAuthRepository();
    await ServiceLocator().init();
  });

  tearDownAll(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  testWidgets('Unauthenticated app starts on Login without Dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EagleFlowApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });
}
