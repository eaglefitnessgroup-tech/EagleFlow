import 'dart:convert';

import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_a4_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_document_footer.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_row.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_table_header.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_totals_block.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_cover_section.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_products_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_layout_spec.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_cover_section_measurer.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'quotation_test_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadQuotationTestFonts);

  const item = QuotationLineItem(
    id: 'row-1',
    name: 'Compact product',
    brand: 'Eagle',
    unitPrice: 100,
    quantity: 1,
  );

  const discountedItem = QuotationLineItem(
    id: 'discounted-row',
    name: 'Discounted product',
    brand: 'Eagle',
    unitPrice: 100,
    quantity: 1,
    discount: 5,
  );

  group('shared quotation layout measurements', () {
    test('paginator and rendered table use the same content widths', () {
      final withDiscount = QuotationLayoutSpec.tableLayoutForItems(const [
        item,
        discountedItem,
      ]);
      final withoutDiscount = QuotationLayoutSpec.tableLayoutForItems(const [
        item,
      ]);

      expect(QuotationLayoutSpec.pageContentWidth, 547);
      expect(QuotationLayoutSpec.tableContentWidth, 543);
      expect(QuotationLayoutSpec.productColumnWidth, closeTo(233.49, 0.001));
      expect(QuotationLayoutSpec.productTextWidth, closeTo(213.49, 0.001));
      // The deployed production table keeps the same seven columns for every
      // quotation, including zero-discount and missing-image rows.
      expect(withDiscount.hasColumn('photo'), isTrue);
      expect(withDiscount.hasColumn('condition'), isFalse);
      expect(withDiscount.hasColumn('discount'), isTrue);
      expect(withoutDiscount.hasColumn('photo'), isTrue);
      expect(withoutDiscount.hasColumn('condition'), isFalse);
      expect(withoutDiscount.hasColumn('discount'), isTrue);
      expect(
        QuotationLayoutSpec.productTextWidthFor(
          QuotationLayoutSpec.productTableLayout,
        ),
        closeTo(213.49, 0.001),
      );
      expect(
        QuotationLayoutSpec.conditionTextWidthFor(
          QuotationLayoutSpec.productTableLayout,
        ),
        0,
      );
    });

    test('compact geometry uses the shared Phase 2 values', () {
      expect(QuotationLayoutSpec.coverCompanyToCustomerSpacing, 20);
      expect(QuotationLayoutSpec.coverBottomSpacing, 8);
      expect(QuotationLayoutSpec.productImageSize, 48);
      expect(QuotationLayoutSpec.productRowVerticalPadding, 2.5);
      expect(QuotationLayoutSpec.tableCellHorizontalPadding, 4);
      expect(QuotationLayoutSpec.productCellHorizontalPadding, 10);
      expect(QuotationLayoutSpec.tableHeaderHeight, 32);
      expect(QuotationLayoutSpec.productRowMinimumHeight, 53.5);
    });

    test('company block measurement matches rendered 8pt rows', () {
      expect(QuotationCoverSectionMeasurer.measureCompanyDetailsHeight(), 84);
    });

    testWidgets('cover estimator matches the rendered preview cover', (
      tester,
    ) async {
      final quotation = QuotationDefaults.createEmptyDraft(
        salespersonId: 'salesperson-id',
      );
      const salespersonName = 'Resolved Salesperson';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: QuotationLayoutSpec.pageContentWidth,
                child: QuotationCoverSection(
                  quotation: quotation,
                  salespersonName: salespersonName,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        QuotationCoverSectionMeasurer.measureHeight(
          quotation,
          salespersonName: salespersonName,
        ),
        closeTo(tester.getSize(find.byType(QuotationCoverSection)).height, 0.1),
      );
    });

    test('resolved salesperson participates in cover measurement', () {
      final quotation = QuotationDefaults.createEmptyDraft(salespersonId: 'ID');

      final fallbackHeight = QuotationCoverSectionMeasurer.measureHeight(
        quotation,
      );
      final resolvedHeight = QuotationCoverSectionMeasurer.measureHeight(
        quotation,
        salespersonName:
            'A deliberately long resolved salesperson display name',
      );

      expect(resolvedHeight, greaterThan(fallbackHeight));
    });

    test('paginator minimum row height uses shared row geometry', () {
      expect(QuotationLayoutSpec.productRowMinimumHeight, 53.5);
      expect(
        QuotationPaginator.estimateProductRowHeight(item),
        QuotationLayoutSpec.productRowMinimumHeight,
      );
    });

    test('corrected product width does not increase row height estimates', () {
      const representativeItem = QuotationLineItem(
        id: 'representative-row',
        name: 'Commercial treadmill',
        brand: 'Eagle',
        description:
            'Dimensions 2200 x 900 x 1600 mm | Motor 7 HP AC | '
            'Maximum user weight 180 kg | Warranty 5 years',
        unitPrice: 100,
        quantity: 1,
      );
      const previousProductTextWidth = 188.85;
      final previousEstimate = QuotationPaginator.estimateProductRowHeight(
        representativeItem,
        productTextWidth: previousProductTextWidth,
      );
      final correctedEstimate = QuotationPaginator.estimateProductRowHeight(
        representativeItem,
      );

      expect(correctedEstimate, lessThanOrEqualTo(previousEstimate));
    });

    testWidgets('preview row uses shared vertical padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
        ),
      );

      final matchingContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(QuotationProductRow),
          matching: find.byType(Container),
        ),
      );
      expect(
        matchingContainers.any(
          (container) =>
              container.padding == QuotationLayoutSpec.productRowPadding,
        ),
        isTrue,
      );
    });

    testWidgets('paginator minimum matches a rendered image row', (
      tester,
    ) async {
      final imageItem = item.copyWith(
        imageBytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: QuotationLayoutSpec.pageContentWidth,
                child: QuotationProductRow(index: 1, item: imageItem),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(QuotationProductRow)).height,
        closeTo(QuotationPaginator.estimateProductRowHeight(imageItem), 0.1),
      );
    });

    testWidgets('preview table header uses shared height and padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: QuotationProductTableHeader())),
      );

      expect(
        tester.getSize(find.byType(QuotationProductTableHeader)).height,
        QuotationLayoutSpec.tableHeaderHeight,
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(QuotationProductTableHeader),
          matching: find.byType(Container),
        ),
      );
      expect(
        container.padding,
        const EdgeInsets.symmetric(
          vertical: QuotationLayoutSpec.tableHeaderVerticalPadding,
          horizontal: QuotationLayoutSpec.tableHorizontalPadding,
        ),
      );
    });

    testWidgets(
      'multi-page totals follow the final product row without a flexible gap',
      (tester) async {
        final quotation = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: const [item],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: QuotationLayoutSpec.pageContentWidth,
                height: QuotationLayoutSpec.productPageAvailableHeight,
                child: QuotationProductsPage(
                  quotation: quotation,
                  model: const QuotationProductsPageModel(
                    items: [item],
                    hasCover: false,
                    hasTotals: true,
                    isLastPage: true,
                  ),
                  startIndex: 0,
                ),
              ),
            ),
          ),
        );

        final pageColumn = tester.widget<Column>(
          find
              .descendant(
                of: find.byType(QuotationProductsPage),
                matching: find.byType(Column),
              )
              .first,
        );
        expect(find.byType(Spacer), findsNothing);
        expect(pageColumn.children.last, isA<QuotationTotalsBlock>());
      },
    );

    testWidgets('single-page totals sit safely just above the footer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(
        QuotationLayoutSpec.a4LogicalWidth,
        QuotationLayoutSpec.a4LogicalHeight,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: const [item],
      );
      final page = QuotationPaginator.paginate(
        quotation,
      ).whereType<QuotationProductsPageModel>().single;

      expect(page.pinTotalsToBottom, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: QuotationA4Page(
            child: QuotationProductsPage(
              quotation: quotation,
              model: page,
              startIndex: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      final productsPage = find.byType(QuotationProductsPage);
      expect(
        find.descendant(of: productsPage, matching: find.byType(Spacer)),
        findsOneWidget,
      );
      final totalsRect = tester.getRect(find.byType(QuotationTotalsBlock));
      final footerRect = tester.getRect(find.byType(QuotationDocumentFooter));
      expect(
        footerRect.top - totalsRect.bottom,
        closeTo(QuotationLayoutSpec.paginationSafetySpacing, 0.1),
      );
      expect(tester.takeException(), isNull);
    });

    test('PDF row uses shared vertical padding', () async {
      final service = QuotationPdfService();
      await service.generatePdf(
        QuotationDefaults.createEmptyDraft().copyWith(lineItems: const [item]),
      );

      final row = service.buildProductRowForTesting(1, item) as pw.Container;
      final padding = row.padding! as pw.EdgeInsets;
      expect(padding.top, QuotationLayoutSpec.productRowVerticalPadding);
      expect(padding.bottom, QuotationLayoutSpec.productRowVerticalPadding);

      final header = service.buildTableHeaderForTesting() as pw.SizedBox;
      expect(header.height, QuotationLayoutSpec.tableHeaderHeight);
      final headerContainer = header.child! as pw.Container;
      final headerPadding = headerContainer.padding! as pw.EdgeInsets;
      expect(headerPadding.top, QuotationLayoutSpec.tableHeaderVerticalPadding);
      expect(headerPadding.left, QuotationLayoutSpec.tableHorizontalPadding);
    });
  });
}
