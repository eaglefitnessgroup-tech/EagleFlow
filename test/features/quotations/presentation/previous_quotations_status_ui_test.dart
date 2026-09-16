import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/previous_quotations_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_filter_bar.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_list_view.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotations_summary_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('summary and filters omit quotation status controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const QuotationsSummaryRow(totalCount: 3, recentCount: 2),
              QuotationFilterBar(
                searchQuery: '',
                sortBy: 'Newest',
                onSearchChanged: (_) {},
                onSortChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Total Quotations'), findsOneWidget);
    expect(find.text('Recent Quotations'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Date Filter'), findsOneWidget);
    expect(find.text('All Status'), findsNothing);
    expect(find.text('Draft'), findsNothing);
    expect(find.text('Sent'), findsNothing);
    expect(find.text('Accepted'), findsNothing);
  });

  test('recent count uses an inclusive rolling 30-day window', () {
    final now = DateTime.utc(2026, 9, 16, 12);

    final quotations = [
      QuotationDefaults.createEmptyDraft().copyWith(createdDate: now),
      QuotationDefaults.createEmptyDraft().copyWith(
        createdDate: now.subtract(const Duration(days: 30)),
      ),
      QuotationDefaults.createEmptyDraft().copyWith(
        createdDate: now.subtract(const Duration(days: 30, seconds: 1)),
      ),
      QuotationDefaults.createEmptyDraft().copyWith(
        createdDate: now.add(const Duration(seconds: 1)),
      ),
    ];

    expect(countRecentQuotations(quotations, now: now), 2);
  });

  testWidgets(
    'desktop row and actions invoke View and Edit independently',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var viewCount = 0;
      var editCount = 0;

      final quotation = QuotationDefaults.createEmptyDraft(
        salespersonId: 'sales-1',
      ).copyWith(
        id: 'quotation-1',
        quotationNumber: 'QT-001',
        customerInfo: QuotationDefaults.createEmptyDraft().customerInfo
            .copyWith(name: 'Example Customer'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationListView(
              quotations: [quotation],
              salespersonNames: const {'sales-1': 'Sales User'},
              onView: (_) => viewCount++,
              onEdit: (_) => editCount++,
              onDuplicate: (_) {},
              onShare: (_) {},
              onDelete: (_) {},
              onCreate: () {},
            ),
          ),
        ),
      );

      expect(find.text('QT-001'), findsOneWidget);
      expect(find.text('Example Customer'), findsOneWidget);
      expect(find.text('Status'), findsNothing);
      expect(find.text('Draft'), findsNothing);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Share PDF'), findsNothing);
      expect(find.text('Duplicate'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.text('QT-001'));
      expect(viewCount, 1);

      await tester.tap(find.text('View'));
      expect(viewCount, 2);

      await tester.tap(find.text('Edit'));
      expect(viewCount, 2);
      expect(editCount, 1);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(viewCount, 2);
      expect(editCount, 1);

      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );
}
