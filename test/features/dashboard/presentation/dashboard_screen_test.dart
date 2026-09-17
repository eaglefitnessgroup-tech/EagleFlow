import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/app/theme/app_colors.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';
import '../../../features/authentication/fake_auth_repository.dart';

void main() {
  late _FakeQuotationRepository quotationRepository;

  setUp(() async {
    ServiceLocator.resetForTesting();

    final dbName = 'test_dashboard_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    ServiceLocator().mockAuthRepository = FakeAuthRepository();
    quotationRepository = _FakeQuotationRepository();
    ServiceLocator().mockQuotationRepository = quotationRepository;
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
        AppRoutes.areaEstimator: (context) =>
            const Scaffold(body: Text('Area Estimator Screen')),
        AppRoutes.stockManagement: (context) =>
            const Scaffold(body: Text('Stock Screen')),
        AppRoutes.profile: (context) =>
            const Scaffold(body: Text('Profile Screen')),
        AppRoutes.createQuotation: (context) =>
            const Scaffold(body: Text('Create Quotation Screen')),
        AppRoutes.quotationPreview: (context) {
          final quotation =
              ModalRoute.of(context)!.settings.arguments! as Quotation;
          return Scaffold(body: Text('Preview ${quotation.quotationNumber}'));
        },
      },
      initialRoute: AppRoutes.dashboard,
    );
  }

  testWidgets('Admin name appears and Stock Management card is visible', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(email: 'anshad@eagleflow.com',
        password: 'anshad123',
        rememberMe: true,
      );
    });

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Greeting should contain user name
    expect(find.textContaining('Anshad'), findsOneWidget);

    // Admin specific card
    expect(find.textContaining('Stock Management'), findsWidgets);

    // Shared actions (Products appears in Grid and BottomNav so findsWidgets is correct)
    expect(find.text('Products'), findsWidgets);
    expect(find.textContaining('Previous Quotations'), findsWidgets);
    expect(find.text('Low Stock'), findsNothing);
  });

  testWidgets('Salesperson name appears and Stock Management card is hidden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await ServiceLocator().authController.login(email: 'ajmal@eagleflow.com',
        password: 'ajmal123',
        rememberMe: true,
      );
    });

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Greeting should contain user name
    expect(find.textContaining('Ajmal'), findsOneWidget);

    // Admin specific card
    expect(find.textContaining('Stock Management'), findsNothing);

    // Shared actions
    expect(find.text('Products'), findsWidgets);
    expect(find.textContaining('Previous Quotations'), findsWidgets);
    expect(find.text('Low Stock'), findsNothing);
  });

  testWidgets(
    'Area Estimator is available to a salesperson and opens its route',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await ServiceLocator().authController.login(
          email: 'ajmal@eagleflow.com',
          password: 'ajmal123',
          rememberMe: true,
        );
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Area Estimator'), findsOneWidget);

      await tester.tap(find.text('Area Estimator'));
      await tester.pumpAndSettle();

      expect(find.text('Area Estimator Screen'), findsOneWidget);
    },
  );

  testWidgets('Stock quick action shows coming-soon dialog without navigating', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();

    expect(find.text('Stock module coming soon.'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Products Screen'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Stock module coming soon.'), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('Null-user fallback does not crash and shows User', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Ensuring no user is logged in
    expect(ServiceLocator().authController.currentUser, isNull);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Greeting should contain user name
    expect(find.textContaining('User'), findsOneWidget);

    // Admin specific card should be hidden
    expect(find.textContaining('Stock Management'), findsNothing);

    // Shared actions
    expect(find.text('Products'), findsWidgets);
    expect(find.textContaining('Previous Quotations'), findsWidgets);
    expect(find.text('Low Stock'), findsNothing);
  });

  testWidgets('Empty database displays zeroes and No quotations yet', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Scroll down to ensure GridView is built
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Total Products'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('No quotations yet'), findsOneWidget);
  });

  testWidgets('Populated data correctly calculates stats', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    quotationRepository.quotations.addAll([
      _quotation(
        id: 'draft',
        customerName: 'Draft Customer',
        quotationNumber: 'QT-DRAFT',
      ),
      _quotation(
        id: 'sent',
        customerName: 'Sent Customer',
        quotationNumber: 'QT-SENT',
        status: QuotationStatus.sent,
      ),
      _quotation(
        id: 'approved',
        customerName: 'Approved Customer',
        quotationNumber: 'QT-APPROVED',
        status: QuotationStatus.approved,
      ),
    ]);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    final totalCard = find.ancestor(
      of: find.text('Total Quotations'),
      matching: find.byType(Container),
    ).first;
    expect(find.descendant(of: totalCard, matching: find.text('3')), findsOneWidget);
    expect(find.text('Pending Quotations'), findsNothing);
  });

  testWidgets('recent draft quotation uses a neutral Saved badge', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final quotation = _quotation(
      id: 'saved-badge',
      customerName: 'Saved Customer',
      quotationNumber: 'QT-SAVED-1',
    );
    quotationRepository.quotations.add(quotation);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(quotation.status, QuotationStatus.draft);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);

    final badge = tester.widget<Container>(
      find.ancestor(
        of: find.text('Saved'),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.statusDraftBg);
    final label = tester.widget<Text>(find.text('Saved'));
    expect(label.style?.color, AppColors.statusDraftText);
  });

  testWidgets(
    'quotation search uses two-character case-insensitive partial matches and caps results',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      quotationRepository.quotations.addAll(
        List.generate(
          9,
          (index) => _quotation(
            id: 'alpha-$index',
            customerName: 'Alpha Customer $index',
            quotationNumber: 'QT-ALPHA-$index',
          ),
        ),
      );

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('dashboard-quotation-search'));
      await tester.enterText(searchField, 'a');
      await tester.pump();
      expect(find.byKey(const Key('dashboard-search-results')), findsNothing);

      await tester.enterText(searchField, 'AL');
      await tester.pump();

      expect(find.byKey(const Key('dashboard-search-results')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'dashboard-search-result-',
              ),
        ),
        findsNWidgets(8),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-search-results')),
          matching: find.text('AED 105.00'),
        ),
        findsNWidgets(8),
      );
    },
  );

  testWidgets('quotation-number match opens the existing preview route', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final quotation = _quotation(
      id: 'special',
      customerName: 'Northwind Trading',
      quotationNumber: 'QT-SPECIAL-204',
    );
    quotationRepository.quotations.add(quotation);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('dashboard-quotation-search')),
      'cial-2',
    );
    await tester.pump();

    final searchResult = find.byKey(
      const Key('dashboard-search-result-special'),
    );
    expect(
      find.descendant(
        of: searchResult,
        matching: find.text('Northwind Trading'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: searchResult, matching: find.text('QT-SPECIAL-204')),
      findsOneWidget,
    );

    await tester.tap(searchResult);
    await tester.pumpAndSettle();

    expect(quotationRepository.previewedQuotation, same(quotation));
    expect(find.text('Preview QT-SPECIAL-204'), findsOneWidget);
  });

  testWidgets('quotation search results fit a narrow mobile dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    quotationRepository.quotations.add(
      _quotation(
        id: 'mobile',
        customerName: 'A Very Long Customer Name For Mobile',
        quotationNumber: 'QT-MOBILE-123456789',
      ),
    );

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('dashboard-quotation-search')),
      'mobile',
    );
    await tester.pump();

    expect(find.byKey(const Key('dashboard-search-results')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Quotation _quotation({
  required String id,
  required String customerName,
  required String quotationNumber,
  QuotationStatus status = QuotationStatus.draft,
}) {
  final now = DateTime(2026, 9, 16);
  return Quotation(
    id: id,
    quotationNumber: quotationNumber,
    customerInfo: CustomerInfo(name: customerName),
    salespersonId: 'salesperson-1',
    createdDate: now,
    modifiedDate: now,
    validUntil: now.add(const Duration(days: 14)),
    expectedDelivery: now.add(const Duration(days: 3)),
    status: status,
    charges: const QuotationCharges(deliveryCharges: 100),
  );
}

class _FakeQuotationRepository implements QuotationRepository {
  final List<Quotation> quotations = [];
  Quotation? previewedQuotation;

  @override
  Future<List<Quotation>> getAllQuotations() async => quotations;

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async {
    previewedQuotation = quotation;
    return quotation;
  }

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async => quotation;

  @override
  Future<void> deleteQuotation(String id) async {}

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) async =>
      sourceQuotation;

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) async =>
      quotations.cast<Quotation?>().firstWhere(
        (quotation) => quotation?.quotationNumber == quotationNumber,
        orElse: () => null,
      );
}
