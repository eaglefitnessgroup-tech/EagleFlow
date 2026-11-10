import 'dart:convert';

import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_a4_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_row.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_totals_block.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_products_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_layout_spec.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'quotation_test_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadQuotationTestFonts);

  test(
    'actual exported PDF renders all 17 items once with safe pagination and totals',
    () async {
      final quotation = _referenceQuotation();
      final items = quotation.lineItems;
      final previewPages = QuotationPaginator.paginate(
        quotation,
        salespersonName: 'Shijo',
      ).whereType<QuotationProductsPageModel>().toList();
      final trace = QuotationPdfRenderTrace();

      final bytes = await QuotationPdfService().generatePdf(
        quotation,
        renderTrace: trace,
      );

      final expectedIds = items.map((item) => item.id).toList();
      final previewIds = previewPages
          .expand((page) => page.items)
          .map((item) => item.id)
          .toList();
      final serializedPdf = latin1.decode(bytes, allowInvalid: true);
      final serializedPageCount = RegExp(
        r'/Type\s*/Page(?!s)',
      ).allMatches(serializedPdf).length;
      final pdfAvailableHeight =
          PdfPageFormat.a4.height -
          QuotationLayoutSpec.pageMargin.vertical -
          QuotationLayoutSpec.footerHeight -
          QuotationLayoutSpec.paginationSafetySpacing;
      expect(bytes, isNotEmpty);
      expect(serializedPageCount, trace.pageCount);
      expect(trace.exportedItemIds, orderedEquals(expectedIds));
      expect(trace.exportedItemIds.toSet(), hasLength(17));
      expect(previewIds, orderedEquals(expectedIds));
      expect(
        trace.productPageItemCounts,
        orderedEquals(previewPages.map((page) => page.items.length)),
      );
      expect(trace.productPageItemCounts.first, inInclusiveRange(7, 9));
      expect(trace.productPageItemCounts, everyElement(greaterThan(0)));
      expect(trace.totalsPageNumbers, hasLength(1));
      expect(trace.totalsPinnedToBottomPageNumbers, isEmpty);
      expect(
        trace.totalsPageNumbers.single,
        trace.productPageItemCounts.length,
      );
      expect(
        trace.productPageUsedHeights,
        everyElement(lessThanOrEqualTo(pdfAvailableHeight + 0.1)),
      );
    },
  );

  test('single-page PDF pins totals above the footer', () async {
    final quotation = QuotationDefaults.createEmptyDraft().copyWith(
      lineItems: const [
        QuotationLineItem(
          id: 'single-page-item',
          productId: 'single-page-product',
          name: 'Compact product',
          brand: 'Eagle',
          unitPrice: 100,
          quantity: 1,
        ),
      ],
    );
    final trace = QuotationPdfRenderTrace();

    final bytes = await QuotationPdfService().generatePdf(
      quotation,
      renderTrace: trace,
    );

    expect(bytes, isNotEmpty);
    expect(trace.productPageItemCounts, [1]);
    expect(trace.totalsPageNumbers, [1]);
    expect(trace.totalsPinnedToBottomPageNumbers, [1]);
    expect(
      trace.productPageUsedHeights.single,
      lessThanOrEqualTo(trace.availablePageHeight + 0.1),
    );
  });

  testWidgets('native A4 preview renders all 17 products across safe pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(
      QuotationLayoutSpec.a4LogicalWidth,
      QuotationLayoutSpec.a4LogicalHeight,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quotation = _referenceQuotation();
    final productPages = QuotationPaginator.paginate(
      quotation,
      salespersonName: 'Shijo',
    ).whereType<QuotationProductsPageModel>().toList();
    expect(productPages, hasLength(2));
    expect(productPages.first.items.length, inInclusiveRange(7, 9));
    expect(productPages.expand((page) => page.items), hasLength(17));

    Future<void> pumpPage(int pageIndex, int startIndex) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuotationA4Page(
            child: QuotationProductsPage(
              quotation: quotation,
              model: productPages[pageIndex],
              startIndex: startIndex,
              salespersonName: 'Shijo',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await pumpPage(0, 0);
    expect(
      find.byType(QuotationProductRow),
      findsNWidgets(productPages.first.items.length),
    );
    expect(find.byType(QuotationTotalsBlock), findsNothing);

    await pumpPage(1, productPages.first.items.length);
    expect(
      find.byType(QuotationProductRow),
      findsNWidgets(productPages.last.items.length),
    );
    expect(find.byType(QuotationTotalsBlock), findsOneWidget);
  });
}

Quotation _referenceQuotation() {
  return QuotationDefaults.createEmptyDraft(salespersonId: 'Shijo').copyWith(
    quotationNumber: 'QT-SH-0053-26',
    revisionNo: 1,
    customerInfo: const CustomerInfo(
      name: 'AHMED AL MANSOURI',
      projectLocation: 'RAS AL KHAIMA',
      phone: '0507990995',
    ),
    lineItems: _referenceItems(),
  );
}

List<QuotationLineItem> _referenceItems() {
  final imageBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  const names = [
    'Recumbent Bike Home',
    'Functional Trainer',
    'Multi Press',
    'High Pulley / Seated Row (Lat Pulldown)',
    'Rubber Dumbbell Set - 2.5kg-25 kg',
    'Dumbbell Rack',
    'Tricep Rope',
    'Adjustable Bench',
    'Rubber Weight Plate - 10 kg',
    'Rubber Weight Plate - 15 kg',
    'Rubber Weight Plate - 20 kg',
    'Rubber Weight Plate - 25 kg',
    'EPDM Rubber Mat - Yellow',
    'V-Shaped Press Down Bar',
    'Aerobic Stepper',
    'Olympic Straight Bar - 20 kg',
    'Deluxe Straight Pro-Style Lat Bar',
  ];
  const descriptions = [
    null,
    null,
    'Dimension 1840x1330x1620mm | Pipe Thickness 3mm | Weight Stack: 100 kg | Net Weight 308 kg | 10 years frame warranty',
    'Dimension 2150x1150x350mm | Weight Stack: 100 kg | Net Weight 255 kg | 10 years frame warranty',
    '2.5-25 kg | 275 kg total',
    'Assembly Size: 245 x 71 x 74 cm | Main Tube: 40 x 80 cm | Net Weight: 51 kg',
    null,
    'Dimension 1240x550x500mm | Net Weight: 28kg | 10 years frame warranty',
    '10 kg',
    '15 kg',
    '20 kg',
    '25 kg',
    'Size - 1m*1m | Thickness - 20mm | Black + 15% Yellow Fleck',
    null,
    null,
    'Chrome finish | Net Weight 20 kg | 2 years warranty',
    null,
  ];
  const prices = <double>[
    2250,
    7000,
    6000,
    6000,
    4000,
    1250,
    50,
    1440,
    120,
    180,
    240,
    300,
    110,
    80,
    250,
    225,
    130,
  ];

  return List.generate(
    names.length,
    (index) => QuotationLineItem(
      id: 'EXPORT-ITEM-${index + 1}',
      productId: 'PRODUCT-${index + 1}',
      productCode: 'CODE-${index + 1}',
      name: names[index],
      brand: index == 12 ? 'FLOORX' : 'PREMIER',
      description: descriptions[index],
      unitPrice: prices[index],
      quantity: index == 12 ? 37 : 1,
      condition: index < 2 || index == 12 ? ProductCondition.newProduct : null,
      imageBytes: imageBytes,
    ),
  );
}
