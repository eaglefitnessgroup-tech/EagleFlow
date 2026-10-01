import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/quotations/application/quotation_family.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/previous_quotations_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_filter_bar.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_list_view.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotations_summary_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DateFilterRepository implements QuotationRepository {
  _DateFilterRepository(this.quotations);

  final List<Quotation> quotations;

  @override
  Future<List<Quotation>> getAllQuotations() async => List.of(quotations);

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async =>
      quotation;

  @override
  Future<Quotation> createRevision(
    String sourceQuotationId,
    Quotation revisionDraft,
  ) async => revisionDraft;

  @override
  Future<void> deleteQuotation(String id) async {}

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
  required String customer,
  required DateTime date,
  String? baseId,
  int revisionNo = 0,
  double? subtotal,
}) {
  return QuotationDefaults.createEmptyDraft(salespersonId: 'sales-1').copyWith(
    id: id,
    quotationNumber: number,
    baseQuotationId: baseId,
    revisionNo: revisionNo,
    createdDate: date,
    modifiedDate: date,
    lineItems: subtotal == null
        ? const []
        : [
            QuotationLineItem(
              id: '$id-item',
              name: 'Display product',
              brand: 'EagleFlow',
              unitPrice: subtotal,
              quantity: 1,
            ),
          ],
    customerInfo: QuotationDefaults.createEmptyDraft().customerInfo.copyWith(
      name: customer,
    ),
  );
}

List<Quotation> _quotations() {
  final alpha = _quotation(
    id: 'alpha',
    number: 'QT-ALPHA',
    customer: 'Alpha Customer',
    date: DateTime(2026, 1, 1, 18, 30),
  );
  return [
    alpha,
    _quotation(
      id: 'alpha-r1',
      number: alpha.quotationNumber,
      customer: 'Alpha Revision',
      date: DateTime(2026, 1, 3, 8),
      baseId: alpha.id,
      revisionNo: 1,
    ),
    _quotation(
      id: 'beta',
      number: 'QT-BETA',
      customer: 'Beta Customer',
      date: DateTime(2026, 1, 5, 23, 59),
      subtotal: 108912,
    ),
    _quotation(
      id: 'gamma',
      number: 'QT-GAMMA',
      customer: 'Gamma Customer',
      date: DateTime(2026, 1, 10, 12),
      subtotal: 452590,
    ),
  ];
}

void main() {
  setUp(() {
    ServiceLocator.resetForTesting();
    ServiceLocator().mockQuotationRepository = _DateFilterRepository(
      _quotations(),
    );
  });
  tearDown(ServiceLocator.resetForTesting);

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(1440, 1000),
    PreviousQuotationDateRangePicker? dateRangePicker,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PreviousQuotationsScreen(dateRangePicker: dateRangePicker),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop content uses full width without horizontal overflow', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(1264, 1000));

    const expectedWidth = 1264 - 64;
    expect(
      tester.getSize(find.byType(QuotationsSummaryRow)).width,
      expectedWidth,
    );
    expect(
      tester.getSize(find.byType(QuotationFilterBar)).width,
      expectedWidth,
    );
    expect(
      tester.getSize(find.byKey(const Key('quotation-desktop-table'))).width,
      expectedWidth,
    );
    final tableRect = tester.getRect(
      find.byKey(const Key('quotation-desktop-table')),
    );
    final actionCenters = <double>[];
    for (final actionKey in [
      'quotation-view-gamma',
      'quotation-edit-gamma',
      'quotation-revise-gamma',
      'quotation-download-gamma',
      'quotation-delete-gamma',
      'quotation-actions-gamma',
    ]) {
      final actionRect = tester.getRect(find.byKey(Key(actionKey)));
      expect(actionRect.left, greaterThanOrEqualTo(tableRect.left));
      expect(actionRect.right, lessThanOrEqualTo(tableRect.right));
      actionCenters.add(actionRect.center.dy);
    }
    for (var index = 1; index < actionCenters.length; index++) {
      expect(
        actionCenters[index],
        closeTo(actionCenters.first, 0.1),
        reason: 'Action at index $index must remain on the same baseline',
      );
    }
    for (final heading in [
      'QT No.',
      'Date',
      'Customer',
      'Salesperson',
      'Amount',
      'Actions',
    ]) {
      expect(find.text(heading), findsOneWidget);
    }
    final dateText = tester.widget<Text>(find.text('Jan 10, 2026'));
    final largeAmountText = tester.widget<Text>(find.text('AED 475,219.50'));
    expect(find.text('AED 114,357.60'), findsOneWidget);
    expect(dateText.overflow, isNull);
    expect(dateText.maxLines, 1);
    expect(dateText.softWrap, isFalse);
    expect(largeAmountText.overflow, isNull);
    expect(largeAmountText.maxLines, 1);
    expect(largeAmountText.softWrap, isFalse);
    expect(largeAmountText.textAlign, TextAlign.right);
    expect(largeAmountText.style?.fontWeight, FontWeight.w500);
    expect(
      tester.getRect(find.text('Jan 10, 2026')).right,
      lessThanOrEqualTo(tableRect.right),
    );
    expect(
      tester.getRect(find.text('AED 475,219.50')).right,
      lessThanOrEqualTo(tableRect.right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop grid preserves complete revision numbers and alignment',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final original = _quotation(
        id: 'grid-base',
        number: 'QT-AN-0028-26',
        customer: 'Grid Customer',
        date: DateTime(2026, 9, 30),
        subtotal: 108912,
      );
      final quotations = [
        original,
        for (final revisionNo in [1, 2, 10])
          _quotation(
            id: 'grid-r$revisionNo',
            number: original.quotationNumber,
            customer: 'Grid Customer R$revisionNo',
            date: DateTime(2026, 9, 30),
            baseId: original.id,
            revisionNo: revisionNo,
            subtotal: 108912,
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuotationListView(
                families: groupQuotationFamilies(quotations),
                salespersonNames: const {'sales-1': 'Salesperson One'},
                onView: (_) {},
                onEdit: (_) {},
                onRevise: (_) {},
                onDownload: (_) {},
                onDuplicate: (_) {},
                onShare: (_) {},
                onDelete: (_) {},
                onCreate: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tableRect = tester.getRect(
        find.byKey(const Key('quotation-desktop-table')),
      );
      for (final entry in {
        'grid-base': 'QT-AN-0028-26',
        'grid-r1': 'QT-AN-0028-26 / R1',
        'grid-r2': 'QT-AN-0028-26 / R2',
        'grid-r10': 'QT-AN-0028-26 / R10',
      }.entries) {
        final numberFinder = find.byKey(Key('quotation-number-${entry.key}'));
        final numberText = tester.widget<Text>(numberFinder);
        final numberRect = tester.getRect(numberFinder);
        expect(numberText.data, entry.value);
        expect(numberText.overflow, isNull);
        expect(numberText.maxLines, 1);
        expect(numberText.softWrap, isFalse);
        expect(numberRect.left, greaterThanOrEqualTo(tableRect.left));
        expect(
          numberRect.right,
          lessThan(
            tester.getRect(find.byKey(Key('quotation-date-${entry.key}'))).left,
          ),
        );
      }

      const rowId = 'grid-r10';
      final leftAlignedColumns = <Key, Key>{
        const Key('quotation-header-number'): const Key(
          'quotation-number-$rowId',
        ),
        const Key('quotation-header-date'): const Key('quotation-date-$rowId'),
        const Key('quotation-header-customer'): const Key(
          'quotation-customer-$rowId',
        ),
        const Key('quotation-header-salesperson'): const Key(
          'quotation-salesperson-$rowId',
        ),
      };
      for (final column in leftAlignedColumns.entries) {
        expect(
          tester.getRect(find.byKey(column.value)).left,
          closeTo(tester.getRect(find.byKey(column.key)).left, 0.1),
        );
      }
      expect(
        tester.getRect(find.byKey(const Key('quotation-amount-$rowId'))).right,
        closeTo(
          tester
              .getRect(find.byKey(const Key('quotation-header-amount')))
              .right,
          0.1,
        ),
      );
      expect(
        tester.getRect(find.byKey(const Key('quotation-actions-$rowId'))).right,
        closeTo(
          tester
              .getRect(find.byKey(const Key('quotation-header-actions')))
              .right,
          0.1,
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('quotation-date-$rowId')))
            .overflow,
        isNull,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('quotation-amount-$rowId')))
            .overflow,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact mobile layout remains responsive', (tester) async {
    await pumpScreen(tester, size: const Size(390, 1000));

    expect(find.byKey(const Key('quotation-mobile-list')), findsOneWidget);
    expect(find.byKey(const Key('quotation-desktop-table')), findsNothing);
    expect(tester.getSize(find.byType(QuotationsSummaryRow)).width, 390 - 48);
    expect(tester.getSize(find.byType(QuotationFilterBar)).width, 390 - 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Date Filter opens the Material date-range picker', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('quotation-date-filter')));
    await tester.pumpAndSettle();

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    expect(find.text('Filter by quotation date'), findsOneWidget);
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('same-day and inclusive range filtering can be cleared', (
    tester,
  ) async {
    var nextRange = DateTimeRange(
      start: DateTime(2026, 1, 5),
      end: DateTime(2026, 1, 5),
    );
    await pumpScreen(tester, dateRangePicker: (_, _) async => nextRange);

    await tester.tap(find.byKey(const Key('quotation-date-filter')));
    await tester.pumpAndSettle();

    expect(find.text('05 Jan 2026 – 05 Jan 2026'), findsOneWidget);
    expect(find.text('QT-BETA'), findsOneWidget);
    expect(find.text('QT-ALPHA'), findsNothing);
    expect(find.text('QT-GAMMA'), findsNothing);
    expect(find.text('Showing 1 of 3 quotations'), findsOneWidget);

    nextRange = DateTimeRange(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 5),
    );
    await tester.tap(find.byKey(const Key('quotation-date-filter')));
    await tester.pumpAndSettle();

    expect(find.text('01 Jan 2026 – 05 Jan 2026'), findsOneWidget);
    expect(find.text('QT-ALPHA'), findsOneWidget);
    expect(find.text('QT-ALPHA / R1'), findsOneWidget);
    expect(find.text('QT-BETA'), findsOneWidget);
    expect(find.text('QT-GAMMA'), findsNothing);
    expect(find.text('Showing 2 of 3 quotations'), findsOneWidget);
    final summary = tester.widget<QuotationsSummaryRow>(
      find.byType(QuotationsSummaryRow),
    );
    expect(summary.totalCount, 3);

    await tester.tap(find.byKey(const Key('quotation-date-filter-clear')));
    await tester.pumpAndSettle();

    expect(find.text('Date Filter'), findsOneWidget);
    expect(find.text('Showing 3 quotations'), findsOneWidget);
    expect(find.text('QT-GAMMA'), findsOneWidget);
  });

  testWidgets('date range combines with search without resetting either', (
    tester,
  ) async {
    final range = DateTimeRange(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 5),
    );
    await pumpScreen(tester, dateRangePicker: (_, _) async => range);

    await tester.enterText(find.byType(TextField).first, 'Alpha');
    await tester.tap(find.byKey(const Key('quotation-date-filter')));
    await tester.pumpAndSettle();

    expect(find.text('01 Jan 2026 – 05 Jan 2026'), findsOneWidget);
    expect(find.text('QT-ALPHA'), findsOneWidget);
    expect(find.text('QT-ALPHA / R1'), findsOneWidget);
    expect(find.text('QT-BETA'), findsNothing);
    expect(find.text('Showing 1 of 3 quotations'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quotation-date-filter-clear')));
    await tester.pumpAndSettle();

    expect(find.text('QT-ALPHA'), findsOneWidget);
    expect(find.text('QT-BETA'), findsNothing);
    expect(find.text('Showing 1 of 3 quotations'), findsOneWidget);
  });

  testWidgets('date range remains active while sort order changes', (
    tester,
  ) async {
    final range = DateTimeRange(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 5),
    );
    await pumpScreen(tester, dateRangePicker: (_, _) async => range);

    await tester.tap(find.byKey(const Key('quotation-date-filter')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('QT-BETA')).dy,
      lessThan(tester.getTopLeft(find.text('QT-ALPHA')).dy),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest').last);
    await tester.pumpAndSettle();

    expect(find.text('01 Jan 2026 – 05 Jan 2026'), findsOneWidget);
    expect(find.text('Showing 2 of 3 quotations'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('QT-ALPHA')).dy,
      lessThan(tester.getTopLeft(find.text('QT-BETA')).dy),
    );
  });
}
