import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quick_quote/presentation/quick_gym_quotation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../authentication/fake_auth_repository.dart';
import 'quick_quote_test_fixture.dart';

void main() {
  setUp(() async {
    ServiceLocator.resetForTesting();
    final database = await databaseFactoryMemory.openDatabase(
      'quick_quote_routing_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);

    final fixture = QuickQuoteFixture();
    final services = ServiceLocator();
    services.mockAuthRepository = FakeAuthRepository();
    services.mockProductRepository = fixture.productRepository;
    services.mockQuotationRepository = _EmptyQuotationRepository();
    services.mockQuickQuoteMappingRepository = fixture.mappingRepository;
    services.mockQuickQuoteActiveConfigRepository =
        fixture.activeConfigRepository;
    await services.init();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  test('registers the Quick Gym Quotation named route', () {
    expect(AppRoutes.quickGymQuotation, '/quick-gym-quotation');
    expect(AppRoutes.routes, contains(AppRoutes.quickGymQuotation));
  });

  testWidgets('named route resolves to QuickGymQuotationScreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.quickGymQuotation,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuickGymQuotationScreen), findsOneWidget);
    final context = tester.element(find.byType(QuickGymQuotationScreen));
    expect(ModalRoute.of(context)?.settings.name, AppRoutes.quickGymQuotation);
  });

  testWidgets('dashboard keeps the existing action and shows Quick Gym entry', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    expect(find.text('New Quotation'), findsOneWidget);
    expect(find.text('Create Now'), findsOneWidget);
    expect(find.text('Quick Gym Quotation'), findsOneWidget);
    expect(
      find.text('Build a full gym quotation from a target budget.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard action opens the named route and back pops normally', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    final action = find.byKey(const Key('dashboard-quick-gym-quotation'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.byType(QuickGymQuotationScreen), findsOneWidget);
    final context = tester.element(find.byType(QuickGymQuotationScreen));
    expect(ModalRoute.of(context)?.settings.name, AppRoutes.quickGymQuotation);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('direct Quick Gym route renders on mobile without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.quickGymQuotation,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuickGymQuotationScreen), findsOneWidget);
    expect(find.byKey(const Key('quick-quote-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(routes: AppRoutes.routes, initialRoute: AppRoutes.dashboard),
  );
  await tester.pumpAndSettle();
}

class _EmptyQuotationRepository implements QuotationRepository {
  @override
  Future<List<Quotation>> getAllQuotations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
