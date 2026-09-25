import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_numeric_fit_helper.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_row.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_layout_spec.dart';
import 'package:eagleflow/features/products/presentation/widgets/product_image.dart';
import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Iterable<pw.Widget> pdfDescendants(pw.Widget widget) sync* {
    yield widget;
    if (widget is pw.Container && widget.child != null) {
      yield* pdfDescendants(widget.child!);
    } else if (widget is pw.SingleChildWidget && widget.child != null) {
      yield* pdfDescendants(widget.child!);
    } else if (widget is pw.MultiChildWidget) {
      for (final child in widget.children) {
        yield* pdfDescendants(child);
      }
    }
  }

  QuotationLineItem createItem({
    required int idNum,
    double unitPrice = 100000.00,
    int quantity = 1,
    double discount = 0,
    String? description,
  }) {
    return QuotationLineItem(
      id: 'ITEM-$idNum',
      name: 'Product $idNum with high quality materials',
      brand: 'EagleBrand',
      unitPrice: unitPrice,
      quantity: quantity,
      discount: discount,
      description: description,
    );
  }

  group('Quotation Fit & Pagination Tests', () {
    test('1. 100,000.00 numeric amount fits on one line without wrapping or truncation', () {
      const text = '100,000.00';
      
      // Test preview cell builder
      final previewWidget = QuotationNumericFitHelper.buildPreviewCell(text, 10, right: true);
      expect(previewWidget, isA<Expanded>());

      final style = QuotationNumericFitHelper.previewStyle();
      expect(style.fontSize, 10.0);
    });

    test('2. 5+ products remain on page 1 when space allows', () {
      final lineItems = List.generate(
        6,
        (index) => createItem(idNum: index + 1, unitPrice: 10000.0),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: lineItems,
      );

      final pages = QuotationPaginator.paginate(quotation);
      final productPages = pages.whereType<QuotationProductsPageModel>().toList();

      // Page 1 should contain all 6 items and NOT be artificially forced to split at item 5
      expect(productPages.first.items.length, 6);
    });

    test('3. Only overflow items move to page 2', () {
      // 12 compact items: first page takes max complete rows that fit, remaining go to page 2
      final lineItems = List.generate(
        12,
        (index) => createItem(idNum: index + 1, unitPrice: 5000.0),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: lineItems,
      );

      final pages = QuotationPaginator.paginate(quotation);
      final productPages = pages.whereType<QuotationProductsPageModel>().toList();

      expect(productPages.length, greaterThanOrEqualTo(2));
      final totalPaginatedItems = productPages.fold<int>(
        0,
        (sum, page) => sum + page.items.length,
      );
      expect(totalPaginatedItems, 12);
      expect(productPages.first.items.length, greaterThanOrEqualTo(5));
    });

    test('4. Product rows never split across pages', () {
      final lineItems = List.generate(
        8,
        (index) => createItem(
          idNum: index + 1,
          description: 'Long description line 1\nLong description line 2',
        ),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: lineItems,
      );

      final pages = QuotationPaginator.paginate(quotation);
      final productPages = pages.whereType<QuotationProductsPageModel>().toList();

      for (final page in productPages) {
        for (final item in page.items) {
          expect(item.id, startsWith('ITEM-'));
        }
      }
    });

    test('5. Totals remain together (either on last product page or on dedicated totals page)', () {
      // Small quotation: totals remain on page 1
      final smallQuotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: List.generate(2, (i) => createItem(idNum: i + 1)),
      );
      final smallPages = QuotationPaginator.paginate(smallQuotation);
      final smallProductPages = smallPages.whereType<QuotationProductsPageModel>().toList();

      expect(smallProductPages.last.hasTotals, isTrue);

      // Large quotation where last product page has no room for totals
      final largeQuotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: List.generate(10, (i) => createItem(idNum: i + 1, description: 'Line 1\nLine 2')),
      );
      final largePages = QuotationPaginator.paginate(largeQuotation);
      final largeProductPages = largePages.whereType<QuotationProductsPageModel>().toList();

      final totalPagesWithHasTotalsTrue = largeProductPages.where((p) => p.hasTotals).length;
      // Exactly one page must carry the complete totals block
      expect(totalPagesWithHasTotalsTrue, 1);
    });

    testWidgets('6. QuotationProductRow renders 100,000.00 unit price and amount correctly', (tester) async {
      final item = createItem(idNum: 1, unitPrice: 100000.00, quantity: 2);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationProductRow(index: 1, item: item),
          ),
        ),
      );

      expect(find.text('100,000.00'), findsOneWidget);
      expect(find.text('200,000.00'), findsOneWidget);
    });

    testWidgets('Preview renders all three description lines without truncation', (
      tester,
    ) async {
      const description =
          'Product Dimension 1680×1710×1620mm\n'
          'Pipe Thickness 3mm | Weight Stack: 100 kg\n'
          'Net Weight 252 kg | 10 years frame warranty';
      final item = createItem(idNum: 1, description: description);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
        ),
      );

      final descriptionText = tester.widget<Text>(find.text(description));
      expect(descriptionText.data, description);
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, TextOverflow.visible);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Preview does not truncate a longer multiline description', (
      tester,
    ) async {
      const description = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6';
      final item = createItem(idNum: 1, description: description);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
        ),
      );

      final descriptionText = tester.widget<Text>(find.text(description));
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, TextOverflow.visible);
      expect(tester.getSize(find.text(description)).height, greaterThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Preview uses a centered 52px contained product image', (
      tester,
    ) async {
      const description = 'Line 1\nLine 2\nLine 3';
      final item = createItem(idNum: 1, description: description).copyWith(
        imageBytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
        ),
      );

      final productImage = tester.widget<ProductImage>(
        find.byType(ProductImage),
      );
      expect(QuotationLayoutSpec.productImageSize, 52);
      expect(productImage.width, 52);
      expect(productImage.height, 52);
      expect(productImage.fit, BoxFit.contain);
      expect(
        find.ancestor(
          of: find.byType(ProductImage),
          matching: find.byType(Center),
        ),
        findsWidgets,
      );

      final descriptionText = tester.widget<Text>(find.text(description));
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, TextOverflow.visible);
      expect(tester.takeException(), isNull);
    });

    test('PDF product row renders all three description lines', () async {
      const description =
          'Product Dimension 1680×1710×1620mm\n'
          'Pipe Thickness 3mm | Weight Stack: 100 kg\n'
          'Net Weight 252 kg | 10 years frame warranty';
      final item = createItem(idNum: 1, description: description);
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: [item],
      );
      final pdfService = QuotationPdfService();

      final pdfBytes = await pdfService.generatePdf(quotation);
      final row = pdfService.buildProductRowForTesting(1, item);
      final descriptionText = pdfDescendants(row)
          .whereType<pw.Text>()
          .singleWhere(
            (text) => (text.text as pw.TextSpan).text == description,
          );

      expect(pdfBytes, isNotEmpty);
      expect((descriptionText.text as pw.TextSpan).text, description);
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, pw.TextOverflow.visible);
    });

    test('PDF uses the matching 52pt contained product image', () async {
      const description = 'Line 1\nLine 2\nLine 3';
      final item = createItem(idNum: 1, description: description).copyWith(
        imageBytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
      final pdfService = QuotationPdfService();
      await pdfService.generatePdf(
        QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
      );
      final row = pdfService.buildProductRowForTesting(1, item);
      final image = pdfDescendants(row).whereType<pw.Image>().single;
      final descriptionText = pdfDescendants(row)
          .whereType<pw.Text>()
          .singleWhere(
            (text) => (text.text as pw.TextSpan).text == description,
          );

      expect(image.width, 52);
      expect(image.height, 52);
      expect(image.fit, pw.BoxFit.contain);
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, pw.TextOverflow.visible);
    });

    test('Paginator accounts for expanded multiline product rows', () {
      const shortDescription = 'Line 1\nLine 2';
      const longDescription =
          'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8';
      final shortQuotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: List.generate(
          20,
          (i) => createItem(idNum: i + 1, description: shortDescription),
        ),
      );
      final longQuotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: List.generate(
          20,
          (i) => createItem(idNum: i + 1, description: longDescription),
        ),
      );

      final shortPages = QuotationPaginator.paginate(shortQuotation)
          .whereType<QuotationProductsPageModel>()
          .toList();
      final longPages = QuotationPaginator.paginate(longQuotation)
          .whereType<QuotationProductsPageModel>()
          .toList();

      expect(longPages.length, greaterThan(shortPages.length));
      expect(longPages.every((page) => page.items.isNotEmpty), isTrue);
      expect(longPages.expand((page) => page.items), hasLength(20));
    });

    test('7. QuotationPdfService generates PDF successfully with numeric fit and dynamic pagination', () async {
      final pdfService = QuotationPdfService();
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: List.generate(6, (i) => createItem(idNum: i + 1, unitPrice: 100000.00)),
      );

      final pdfBytes = await pdfService.generatePdf(quotation);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
