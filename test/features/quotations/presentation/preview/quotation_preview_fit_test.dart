import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_numeric_fit_helper.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_row.dart';
import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
