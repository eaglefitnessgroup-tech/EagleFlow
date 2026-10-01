import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/previous_quotations_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotations_summary_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FamilyRepository implements QuotationRepository {
  _FamilyRepository(this.quotations);

  final List<Quotation> quotations;
  Quotation? imageRequest;
  final List<String> deletedIds = [];

  @override
  Future<List<Quotation>> getAllQuotations() async => List.of(quotations);

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async {
    imageRequest = quotation;
    return quotation;
  }

  @override
  Future<Quotation> createRevision(
    String sourceQuotationId,
    Quotation revisionDraft,
  ) async => revisionDraft;

  @override
  Future<void> deleteQuotation(String id) async {
    deletedIds.add(id);
    quotations.removeWhere((quotation) => quotation.id == id);
  }

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) async =>
      sourceQuotation;

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) async => null;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async => quotation;
}

Quotation _quotation({
  required String id,
  required String number,
  String? baseId,
  int revisionNo = 0,
  required String customer,
}) {
  return QuotationDefaults.createEmptyDraft(salespersonId: 'sales-1').copyWith(
    id: id,
    quotationNumber: number,
    baseQuotationId: baseId,
    revisionNo: revisionNo,
    customerInfo: QuotationDefaults.createEmptyDraft().customerInfo.copyWith(
      name: customer,
    ),
  );
}

void main() {
  setUp(ServiceLocator.resetForTesting);
  tearDown(ServiceLocator.resetForTesting);

  testWidgets('search by revision filters flat rows and counts families', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final original = _quotation(
      id: 'base',
      number: 'QT-AN-0027-26',
      customer: 'Original Customer',
    );
    final r1 = _quotation(
      id: 'r1',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 1,
      customer: 'First Customer',
    );
    final r2 = _quotation(
      id: 'r2',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 2,
      customer: 'Revision Match Customer',
    );
    final standalone = _quotation(
      id: 'standalone',
      number: 'QT-AN-0028-26',
      customer: 'Other Customer',
    );
    ServiceLocator().mockQuotationRepository = _FamilyRepository([
      original,
      r1,
      r2,
      standalone,
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: PreviousQuotationsScreen()),
    );
    await tester.pumpAndSettle();

    final summary = tester.widget<QuotationsSummaryRow>(
      find.byType(QuotationsSummaryRow),
    );
    expect(summary.totalCount, 2);
    expect(summary.recentCount, 2);
    expect(find.text('Showing 2 quotations'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R1'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'R2');
    await tester.pump();

    expect(find.text('Showing 1 of 2 quotations'), findsOneWidget);
    expect(find.text('QT-AN-0027-26'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R2'), findsOneWidget);
    expect(find.text('Latest'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Revision Match');
    await tester.pump();
    expect(find.text('QT-AN-0027-26 / R2'), findsOneWidget);
    expect(find.text('QT-AN-0028-26'), findsNothing);
  });

  testWidgets(
    'Revise loads the selected revision and opens revision controller',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final original = _quotation(
        id: 'base',
        number: 'QT-AN-0027-26',
        customer: 'Original Customer',
      );
      final latest = _quotation(
        id: 'r1',
        number: original.quotationNumber,
        baseId: original.id,
        revisionNo: 1,
        customer: 'Latest Customer',
      );
      final repository = _FamilyRepository([original, latest]);
      ServiceLocator().mockQuotationRepository = repository;
      Object? capturedArguments;

      await tester.pumpWidget(
        MaterialApp(
          home: const PreviousQuotationsScreen(),
          onGenerateRoute: (settings) {
            capturedArguments = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  const Scaffold(body: Text('Revision editor route')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quotation-revise-r1')));
      await tester.pumpAndSettle();

      expect(repository.imageRequest?.id, 'r1');
      expect(capturedArguments, isA<QuotationController>());
      final controller = capturedArguments! as QuotationController;
      expect(controller.isRevisionDraft, isTrue);
      expect(controller.revisionSourceQuotationId, 'r1');
      expect(controller.quotation.id, isEmpty);
      expect(controller.quotation.baseQuotationId, 'base');
      expect(controller.quotation.revisionNo, 2);
      expect(controller.quotation.customerInfo.name, 'Latest Customer');
      expect(latest.id, 'r1');
    },
  );

  for (final surface in <({String name, Size size})>[
    (name: 'desktop', size: const Size(1500, 900)),
    (name: 'mobile', size: const Size(390, 900)),
  ]) {
    testWidgets(
      '${surface.name} refreshes delete eligibility after each latest revision deletion',
      (tester) async {
        tester.view.physicalSize = surface.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final original = _quotation(
          id: 'base',
          number: 'QT-AN-0027-26',
          customer: 'Original Customer',
        );
        final r1 = _quotation(
          id: 'r1',
          number: original.quotationNumber,
          baseId: original.id,
          revisionNo: 1,
          customer: 'R1 Customer',
        );
        final r2 = _quotation(
          id: 'r2',
          number: original.quotationNumber,
          baseId: original.id,
          revisionNo: 2,
          customer: 'R2 Customer',
        );
        final standalone = _quotation(
          id: 'standalone',
          number: 'QT-AN-0028-26',
          customer: 'Standalone Customer',
        );
        final repository = _FamilyRepository([original, r1, r2, standalone]);
        ServiceLocator().mockQuotationRepository = repository;

        Future<bool> deleteEnabled(String id) async {
          final actions = find.byKey(Key('quotation-actions-$id'));
          await tester.ensureVisible(actions);
          await tester.pumpAndSettle();
          await tester.tap(actions);
          await tester.pumpAndSettle();
          final item = tester.widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          );
          final enabled = item.enabled;
          Navigator.of(tester.element(find.text('Share'))).pop();
          await tester.pumpAndSettle();
          return enabled;
        }

        Future<void> deleteVersion(String id) async {
          final actions = find.byKey(Key('quotation-actions-$id'));
          await tester.ensureVisible(actions);
          await tester.pumpAndSettle();
          await tester.tap(actions);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          const MaterialApp(home: PreviousQuotationsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Showing 2 quotations'), findsOneWidget);
        expect(await deleteEnabled('base'), isFalse);
        expect(await deleteEnabled('r1'), isFalse);
        expect(await deleteEnabled('r2'), isTrue);

        await deleteVersion('r2');

        expect(repository.deletedIds, ['r2']);
        expect(find.text('QT-AN-0027-26 / R2'), findsNothing);
        expect(find.text('QT-AN-0027-26 / R1'), findsOneWidget);
        expect(find.text('Showing 2 quotations'), findsOneWidget);
        expect(await deleteEnabled('base'), isFalse);
        expect(await deleteEnabled('r1'), isTrue);

        await deleteVersion('r1');

        expect(repository.deletedIds, ['r2', 'r1']);
        expect(find.text('QT-AN-0027-26 / R1'), findsNothing);
        expect(find.text('QT-AN-0027-26'), findsOneWidget);
        expect(find.text('Showing 2 quotations'), findsOneWidget);
        expect(await deleteEnabled('base'), isTrue);
        expect(original.revisionNo, 0);
        expect(r1.revisionNo, 1);
        expect(r2.revisionNo, 2);
      },
    );
  }
}
