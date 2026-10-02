import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/presentation/create_quotation_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/customer_information_card.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/selected_products_section.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_result.dart';
import 'package:eagleflow/features/quick_quote/presentation/quick_gym_quotation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../../authentication/fake_auth_repository.dart';
import '../quick_quote_test_fixture.dart';

void main() {
  late QuickQuoteFixture fixture;
  late _TrackingQuotationRepository quotationRepository;

  setUp(() async {
    ServiceLocator.resetForTesting();
    final database = await databaseFactoryMemory.openDatabase(
      'quick_quote_handoff_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);

    fixture = QuickQuoteFixture();
    quotationRepository = _TrackingQuotationRepository();
    final services = ServiceLocator();
    services.mockAuthRepository = FakeAuthRepository();
    services.mockProductRepository = fixture.productRepository;
    services.mockQuotationRepository = quotationRepository;
    services.mockQuickQuoteMappingRepository = fixture.mappingRepository;
    await services.init();
    services.authController.setCurrentUserForTesting(
      AppUser(
        id: 'salesperson-current',
        name: 'Current Salesperson',
        username: 'salesperson',
        passwordHash: 'hash',
        role: UserRole.sales,
        createdAt: DateTime.utc(2026, 10),
        updatedAt: DateTime.utc(2026, 10),
      ),
    );
    await services.productMasterController.loadProducts();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  testWidgets(
    'Continue hands an ordinary editable draft to the existing editor flow',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await fixture.initialize();
      expect(
        await tester.runAsync(() => fixture.controller.generate('100000')),
        isTrue,
      );
      final result = fixture.controller.result!;
      expect(quotationRepository.saveCalls, 0);

      Quotation? handedOffDraft;
      Object? previewArguments;
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.createQuotation: (context) {
              handedOffDraft =
                  ModalRoute.of(context)!.settings.arguments! as Quotation;
              return const CreateQuotationScreen();
            },
            AppRoutes.quotationPreview: (context) {
              previewArguments = ModalRoute.of(context)!.settings.arguments;
              return const Scaffold(body: Text('Existing Preview Route'));
            },
          },
          home: QuickGymQuotationScreen(
            controller: fixture.controller,
            initializeOnMount: false,
          ),
        ),
      );
      await tester.pump();

      final continueButton = find.byKey(
        const Key('continue-to-quotation-button'),
      );
      expect(continueButton, findsOneWidget);
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CreateQuotationScreen), findsOneWidget);
      expect(handedOffDraft, isNotNull);
      expect(handedOffDraft!.id, isEmpty);
      expect(handedOffDraft!.quotationNumber, isEmpty);
      expect(handedOffDraft!.baseQuotationId, isNull);
      expect(handedOffDraft!.revisionNo, 0);
      expect(handedOffDraft!.salespersonId, 'salesperson-current');
      expect(quotationRepository.saveCalls, 0);
      expect(quotationRepository.createRevisionCalls, 0);

      var section = tester.widget<SelectedProductsSection>(
        find.byType(SelectedProductsSection),
      );
      expect(section.items, hasLength(result.selections.length));
      expect(
        section.items.map((item) => item.productId),
        result.selections.map((selection) => selection.productId),
      );
      expect(
        section.items.map((item) => item.quantity),
        result.selections.map((selection) => selection.quantity),
      );

      final extraProduct = fixture.products.firstWhere(
        (product) => !section.items.any((item) => item.productId == product.id),
      );
      section.onProductsAdded([extraProduct]);
      await tester.pump();
      section = tester.widget<SelectedProductsSection>(
        find.byType(SelectedProductsSection),
      );
      expect(section.items.last.productId, extraProduct.id);

      final removedId = section.items.first.id;
      section.onRemove(removedId);
      await tester.pump();
      section = tester.widget<SelectedProductsSection>(
        find.byType(SelectedProductsSection),
      );
      expect(section.items.any((item) => item.id == removedId), isFalse);

      final quantityItem = section.items.first;
      section.onQuantityChanged(quantityItem.id, 7);
      await tester.pump();
      section = tester.widget<SelectedProductsSection>(
        find.byType(SelectedProductsSection),
      );
      expect(
        section.items
            .singleWhere((item) => item.id == quantityItem.id)
            .quantity,
        7,
      );

      final firstBeforeReorder = section.items.first.id;
      section.onReorder(0, 2);
      await tester.pump();
      section = tester.widget<SelectedProductsSection>(
        find.byType(SelectedProductsSection),
      );
      expect(section.items[1].id, firstBeforeReorder);
      expect(
        find.byKey(
          ValueKey('quotation-item-drag-handle-${section.items.first.id}'),
        ),
        findsOneWidget,
      );

      final customerCard = tester.widget<CustomerInformationCard>(
        find.byType(CustomerInformationCard),
      );
      customerCard.onNameChanged!('Quick Quote Customer');
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Preview Quotation'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Existing Preview Route'), findsOneWidget);
      expect(previewArguments, isA<QuotationController>());

      Navigator.of(
        tester.element(find.text('Existing Preview Route')),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(quotationRepository.saveCalls, 1);
      expect(quotationRepository.createRevisionCalls, 0);
      expect(quotationRepository.savedQuotation?.baseQuotationId, isNull);
      expect(quotationRepository.savedQuotation?.revisionNo, 0);
    },
  );

  testWidgets('insufficient-budget result has no handoff action', (
    tester,
  ) async {
    await fixture.initialize();
    expect(
      await tester.runAsync(() => fixture.controller.generate('1')),
      isTrue,
    );
    expect(
      fixture.controller.result!.status,
      QuickQuoteBudgetStatus.insufficientBudget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QuickGymQuotationScreen(
          controller: fixture.controller,
          initializeOnMount: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Minimum Balanced Total'), findsOneWidget);
    expect(find.text('Shortfall'), findsOneWidget);
    expect(find.byKey(const Key('continue-to-quotation-button')), findsNothing);
    expect(quotationRepository.saveCalls, 0);
  });
}

class _TrackingQuotationRepository implements QuotationRepository {
  int saveCalls = 0;
  int createRevisionCalls = 0;
  Quotation? savedQuotation;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    saveCalls++;
    savedQuotation = quotation;
    return quotation.copyWith(id: 'saved-id', quotationNumber: 'QT-TEST');
  }

  @override
  Future<Quotation> createRevision(
    String sourceQuotationId,
    Quotation revisionDraft,
  ) async {
    createRevisionCalls++;
    return revisionDraft;
  }

  @override
  Future<List<Quotation>> getAllQuotations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
