import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';

void main() {
  group('Quotation Preview Layout Stabilization', () {
    late Quotation filledQuotation;

    setUp(() {
      filledQuotation = QuotationDefaults.createEmptyDraft().copyWith(
        customerInfo: const CustomerInfo(
          name: 'John Doe',
          company: 'Acme Corp',
          phone: '123-456-7890',
          email: 'john@acme.com',
          projectLocation: 'Dubai Marina',
        ),
      );
    });

    testWidgets('QuotationPreviewScreen renders without overflow at 320x800', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;

      final controller = QuotationController(filledQuotation);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(arguments: controller),
              builder: (context) => const QuotationPreviewScreen(),
            );
          },
        ),
      );

      expect(tester.takeException(), isNull);

      // Verify layout specifics

      // Website
      expect(find.text('eaglefitnessgroup.com'), findsOneWidget);

      // Company Details
      expect(find.textContaining('982901'), findsOneWidget);
      expect(
        find.textContaining('MAX EAGLE FITNESS SPORT EQUIPMENT TRADING LLC'),
        findsOneWidget,
      );
      expect(find.textContaining('SH03, INDUSTRIAL AREA 18'), findsOneWidget);
      expect(find.textContaining('+971 56 507 7088'), findsOneWidget);
      expect(find.textContaining('100456705100003'), findsOneWidget);

      // Customer Info labels
      expect(find.text('QUOTATION TO'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Dubai Marina'), findsOneWidget);
      expect(find.text('123-456-7890'), findsOneWidget);

      // Document Info
      expect(
        find.text('QUOTATION'),
        findsNothing,
      ); // Removed from bottom right block

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('1 product fits on first page with totals', (
      WidgetTester tester,
    ) async {
      final quotation = filledQuotation.copyWith(
        lineItems: [
          const QuotationLineItem(
            id: '1',
            productId: 'p1',
            name: 'Product 1',
            brand: 'B',
            quantity: 1,
            unitPrice: 100,
          ),
        ],
      );
      final pages = QuotationPaginator.paginate(quotation);
      expect(pages.length, 2);
      expect(pages[pages.length - 1], isA<QuotationInfoPageModel>());

      final docPages = pages.take(pages.length - 1).toList();
      expect(docPages.length, 1);
      final page = docPages[0] as QuotationProductsPageModel;
      expect(page.hasCover, isTrue);
      expect(page.hasTotals, isTrue);
      expect(page.items.length, 1);
    });

    testWidgets('3 standard products + totals fit on Page 1', (
      WidgetTester tester,
    ) async {
      final List<QuotationLineItem> items = List.generate(
        3,
        (i) => QuotationLineItem(
          id: 'id_$i',
          productId: 'p_$i',
          name: 'Item $i',
          brand: 'Generic',
          quantity: 1,
          unitPrice: 100,
        ),
      );
      final quotation = filledQuotation.copyWith(lineItems: items);
      final pages = QuotationPaginator.paginate(quotation);

      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();
      expect(productPages.length, 1);
      expect(productPages.first.items.length, 3);
      expect(productPages.first.hasTotals, isTrue);
    });

    testWidgets('4 standard products + totals fit on Page 1', (
      WidgetTester tester,
    ) async {
      final List<QuotationLineItem> items = List.generate(
        4,
        (i) => QuotationLineItem(
          id: 'id_$i',
          productId: 'p_$i',
          name: 'Item $i',
          brand: 'Generic',
          quantity: 1,
          unitPrice: 100,
        ),
      );
      final quotation = filledQuotation.copyWith(lineItems: items);
      final pages = QuotationPaginator.paginate(quotation);

      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();
      expect(productPages.length, 1);
      expect(productPages.first.items.length, 4);
      expect(productPages.first.hasTotals, isTrue);
    });

    testWidgets(
      '5 products: Page 1 contains 5 products, totals move to Page 2',
      (WidgetTester tester) async {
        final List<QuotationLineItem> items = List.generate(
          5,
          (i) => QuotationLineItem(
            id: 'id_$i',
            productId: 'p_$i',
            name: 'Item $i',
            brand: 'Generic',
            quantity: 1,
            unitPrice: 100,
          ),
        );
        final quotation = filledQuotation.copyWith(lineItems: items);
        final pages = QuotationPaginator.paginate(quotation);

        final productPages = pages
            .whereType<QuotationProductsPageModel>()
            .toList();
        expect(productPages.length, 2);
        expect(productPages[0].items.length, 5);
        expect(productPages[0].hasTotals, isFalse);
        expect(productPages[1].items.length, 0);
        expect(productPages[1].hasTotals, isTrue);
      },
    );

    testWidgets(
      '6 products: Page 1 contains 5 products, Page 2 contains product 6 + totals',
      (WidgetTester tester) async {
        final List<QuotationLineItem> items = List.generate(
          6,
          (i) => QuotationLineItem(
            id: 'id_$i',
            productId: 'p_$i',
            name: 'Item $i',
            brand: 'Generic',
            quantity: 1,
            unitPrice: 100,
          ),
        );
        final quotation = filledQuotation.copyWith(lineItems: items);
        final pages = QuotationPaginator.paginate(quotation);

        final productPages = pages
            .whereType<QuotationProductsPageModel>()
            .toList();
        expect(productPages.length, 2);
        expect(productPages[0].items.length, 5);
        expect(productPages[0].hasTotals, isFalse);
        expect(productPages[1].items.length, 1);
        expect(productPages[1].hasTotals, isTrue);
      },
    );

    testWidgets(
      '9 products: Page 1 contains 5 products, Page 2 contains 4 products + totals',
      (WidgetTester tester) async {
        final List<QuotationLineItem> items = List.generate(
          9,
          (i) => QuotationLineItem(
            id: 'id_$i',
            productId: 'p_$i',
            name: 'Item $i',
            brand: 'Generic',
            quantity: 1,
            unitPrice: 100,
          ),
        );
        final quotation = filledQuotation.copyWith(lineItems: items);
        final pages = QuotationPaginator.paginate(quotation);

        final productPages = pages
            .whereType<QuotationProductsPageModel>()
            .toList();
        expect(productPages.length, 2);
        expect(productPages[0].items.length, 5);
        expect(productPages[0].hasTotals, isFalse);
        expect(productPages[1].items.length, 4);
        expect(productPages[1].hasTotals, isTrue);
      },
    );

    testWidgets('Products with two-line titles/descriptions pack correctly', (
      WidgetTester tester,
    ) async {
      final List<QuotationLineItem> items = List.generate(
        3, // 3 tall items should still fit comfortably on one page
        (i) => QuotationLineItem(
          id: 'id_$i',
          productId: 'p_$i',
          name:
              'Very long product name that will wrap to two lines easily because it is quite long',
          brand: 'Generic',
          description:
              'A similarly long description that will also naturally wrap to two lines',
          quantity: 1,
          unitPrice: 100,
        ),
      );
      final quotation = filledQuotation.copyWith(lineItems: items);
      final pages = QuotationPaginator.paginate(quotation);

      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();
      expect(productPages.length, 1);
      expect(productPages.first.items.length, 3);
      expect(productPages.first.hasTotals, isTrue);
    });

    testWidgets('12 products produce predictable pagination', (
      WidgetTester tester,
    ) async {
      final List<QuotationLineItem> items = List.generate(
        12,
        (i) => QuotationLineItem(
          id: 'id_$i',
          productId: 'p_$i',
          name: 'Item $i',
          brand: 'Generic',
          quantity: 1,
          unitPrice: 100,
        ),
      );
      final quotation = filledQuotation.copyWith(lineItems: items);
      final pages = QuotationPaginator.paginate(quotation);
      expect(pages[pages.length - 1], isA<QuotationInfoPageModel>());

      final docPages = pages.take(pages.length - 1).toList();

      final productPages = docPages
          .whereType<QuotationProductsPageModel>()
          .toList();
      expect(productPages.length, greaterThanOrEqualTo(1));

      final allItems = productPages.expand((p) => p.items).toList();
      expect(allItems.length, 12);
    });

    testWidgets(
      '25 mixed products produce predictable pagination with unchanged order',
      (WidgetTester tester) async {
        final List<QuotationLineItem> items = List.generate(
          25,
          (i) => QuotationLineItem(
            id: 'id_$i',
            productId: 'p_$i',
            name: i % 3 == 0
                ? 'Very long product name that might wrap if not careful $i'
                : 'Item $i',
            brand: 'Generic',
            description: i % 4 == 0
                ? 'Some description for product $i to make row taller'
                : null,
            quantity: 1,
            unitPrice: 100,
          ),
        );
        final quotation = filledQuotation.copyWith(lineItems: items);
        final pages = QuotationPaginator.paginate(quotation);
        expect(pages[pages.length - 1], isA<QuotationInfoPageModel>());

        final docPages = pages.take(pages.length - 1).toList();

        final productPages = docPages
            .whereType<QuotationProductsPageModel>()
            .toList();
        final allItems = productPages.expand((p) => p.items).toList();

        expect(allItems.length, 25);
        for (int i = 0; i < 25; i++) {
          expect(allItems[i].id, 'id_$i');
        }
      },
    );

    testWidgets('Orphan balancing works for 1 spilled item if safe', (
      WidgetTester tester,
    ) async {
      final List<QuotationLineItem> items = List.generate(
        30,
        (i) => QuotationLineItem(
          id: 'id_$i',
          productId: 'p_$i',
          name: 'Item $i',
          brand: 'Generic',
          quantity: 1,
          unitPrice: 100,
        ),
      );

      for (int count = 1; count <= 30; count++) {
        final quotation = filledQuotation.copyWith(
          lineItems: items.take(count).toList(),
        );
        final pages = QuotationPaginator.paginate(quotation);
        expect(pages[pages.length - 1], isA<QuotationInfoPageModel>());

        final docPages = pages.take(pages.length - 1).toList();

        final productPages = docPages
            .whereType<QuotationProductsPageModel>()
            .toList();

        if (productPages.length > 1) {
          final allItems = productPages.expand((p) => p.items).toList();
          expect(allItems.length, count);
        }
      }
    });
  });
}
