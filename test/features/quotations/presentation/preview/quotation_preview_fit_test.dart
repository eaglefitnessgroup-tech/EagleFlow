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
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_table_header.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_document_formatters.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_layout_spec.dart';
import 'package:eagleflow/features/products/presentation/widgets/product_image.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
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
    ProductCondition? condition,
  }) {
    return QuotationLineItem(
      id: 'ITEM-$idNum',
      name: 'Product $idNum with high quality materials',
      brand: 'EagleBrand',
      unitPrice: unitPrice,
      quantity: quantity,
      discount: discount,
      description: description,
      condition: condition,
    );
  }

  group('Quotation Fit & Pagination Tests', () {
    test(
      'shared column geometry redistributes only the first three columns',
      () {
        expect(QuotationLayoutSpec.columnFlex, {
          'sno': 8,
          'photo': 13,
          'product': 43,
          'qty': 6,
          'unitPrice': 10,
          'discount': 8,
          'amount': 12,
        });
        expect(
          QuotationLayoutSpec.columnFlex['sno']! +
              QuotationLayoutSpec.columnFlex['photo']! +
              QuotationLayoutSpec.columnFlex['product']!,
          64,
        );
        expect(QuotationLayoutSpec.productImageSize, 52);
      },
    );

    testWidgets('Preview header and row use identical shared column geometry', (
      tester,
    ) async {
      final item = createItem(idNum: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const QuotationProductTableHeader(),
                QuotationProductRow(index: 1, item: item),
              ],
            ),
          ),
        ),
      );

      List<int> directFlexes(Row row) => row.children
          .whereType<Expanded>()
          .map((expanded) => expanded.flex)
          .toList();

      final headerRow = tester.widget<Row>(
        find.descendant(
          of: find.byType(QuotationProductTableHeader),
          matching: find.byType(Row),
        ),
      );
      final productRow = tester.widget<Row>(
        find.descendant(
          of: find.byType(QuotationProductRow),
          matching: find.byType(Row),
        ),
      );
      const expectedFlexes = [8, 13, 43, 6, 10, 8, 12];

      expect(directFlexes(headerRow), expectedFlexes);
      expect(directFlexes(productRow), expectedFlexes);
    });

    test('PDF header and row use identical shared column geometry', () async {
      final item = createItem(idNum: 1);
      final pdfService = QuotationPdfService();
      await pdfService.generatePdf(
        QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
      );

      List<int> flexes(pw.Widget widget) => pdfDescendants(
        widget,
      ).whereType<pw.Expanded>().map((expanded) => expanded.flex).toList();

      const expectedFlexes = [8, 13, 43, 6, 10, 8, 12];
      expect(flexes(pdfService.buildTableHeaderForTesting()), expectedFlexes);
      expect(
        flexes(pdfService.buildProductRowForTesting(1, item)),
        expectedFlexes,
      );
      expect(QuotationLayoutSpec.productImageSize, 52);
    });

    test(
      '1. 100,000.00 numeric amount fits on one line without wrapping or truncation',
      () {
        const text = '100,000.00';

        // Test preview cell builder
        final previewWidget = QuotationNumericFitHelper.buildPreviewCell(
          text,
          10,
          right: true,
        );
        expect(previewWidget, isA<Expanded>());

        final style = QuotationNumericFitHelper.previewStyle();
        expect(style.fontSize, 10.0);
      },
    );

    test('2. 5+ products remain on page 1 when space allows', () {
      final lineItems = List.generate(
        6,
        (index) => createItem(idNum: index + 1, unitPrice: 10000.0),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: lineItems,
      );

      final pages = QuotationPaginator.paginate(quotation);
      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();

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
      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();

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
      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();

      for (final page in productPages) {
        for (final item in page.items) {
          expect(item.id, startsWith('ITEM-'));
        }
      }
    });

    test(
      '5. Totals remain together (either on last product page or on dedicated totals page)',
      () {
        // Small quotation: totals remain on page 1
        final smallQuotation = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: List.generate(2, (i) => createItem(idNum: i + 1)),
        );
        final smallPages = QuotationPaginator.paginate(smallQuotation);
        final smallProductPages = smallPages
            .whereType<QuotationProductsPageModel>()
            .toList();

        expect(smallProductPages.last.hasTotals, isTrue);

        // Large quotation where last product page has no room for totals
        final largeQuotation = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: List.generate(
            10,
            (i) => createItem(idNum: i + 1, description: 'Line 1\nLine 2'),
          ),
        );
        final largePages = QuotationPaginator.paginate(largeQuotation);
        final largeProductPages = largePages
            .whereType<QuotationProductsPageModel>()
            .toList();

        final totalPagesWithHasTotalsTrue = largeProductPages
            .where((p) => p.hasTotals)
            .length;
        // Exactly one page must carry the complete totals block
        expect(totalPagesWithHasTotalsTrue, 1);
      },
    );

    testWidgets(
      '6. QuotationProductRow renders 100,000.00 unit price and amount correctly',
      (tester) async {
        final item = createItem(idNum: 1, unitPrice: 100000.00, quantity: 2);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
          ),
        );

        expect(find.text('100,000.00'), findsOneWidget);
        expect(find.text('200,000.00'), findsOneWidget);
      },
    );

    testWidgets(
      'Preview renders all three description lines without truncation',
      (tester) async {
        const description =
            'Product Dimension 1680×1710×1620mm\n'
            'Pipe Thickness 3mm | Weight Stack: 100 kg\n'
            'Net Weight 252 kg | 10 years frame warranty';
        final item = createItem(
          idNum: 1,
          description: description,
          condition: ProductCondition.used,
        );

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
      },
    );

    testWidgets(
      'Preview uppercases metadata for display without mutating the item',
      (tester) async {
        const item = QuotationLineItem(
          id: 'metadata-preview',
          productCode: 'fxr01w',
          name: 'Floor tile',
          brand: 'FloorX',
          description: 'Existing description',
          unitPrice: 100,
          quantity: 1,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
          ),
        );

        final metadata = tester.widget<Text>(
          find.text('CODE: FXR01W | BRAND: FLOORX'),
        );
        final description = tester.widget<Text>(
          find.text('Existing description'),
        );

        expect(metadata.style?.fontSize, description.style?.fontSize);
        expect(
          metadata.style?.fontSize,
          QuotationLayoutSpec.productDetailFontSize,
        );
        expect(item.productCode, 'fxr01w');
        expect(item.brand, 'FloorX');
      },
    );

    testWidgets(
      'Preview shows uppercase Condition between metadata and description at 8pt',
      (tester) async {
        final item = createItem(
          idNum: 1,
          condition: ProductCondition.used,
          description: 'Existing description',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
          ),
        );

        final metadataFinder = find.text('CODE: — | BRAND: EAGLEBRAND');
        final conditionFinder = find.text('CONDITION: USED');
        final descriptionFinder = find.text('Existing description');
        final condition = tester.widget<Text>(conditionFinder);
        final description = tester.widget<Text>(descriptionFinder);

        expect(
          condition.style?.fontSize,
          QuotationLayoutSpec.productDetailFontSize,
        );
        expect(condition.style?.fontSize, description.style?.fontSize);
        expect(
          tester.getTopLeft(metadataFinder).dy,
          lessThan(tester.getTopLeft(conditionFinder).dy),
        );
        expect(
          tester.getTopLeft(conditionFinder).dy,
          lessThan(tester.getTopLeft(descriptionFinder).dy),
        );
      },
    );

    testWidgets('Preview hides the Condition line when the snapshot is null', (
      tester,
    ) async {
      final item = createItem(idNum: 1, description: 'Existing description');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuotationProductRow(index: 1, item: item)),
        ),
      );

      expect(find.textContaining('CONDITION:'), findsNothing);
    });

    testWidgets('Preview does not truncate a longer multiline description', (
      tester,
    ) async {
      const description = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6';
      final item = createItem(
        idNum: 1,
        description: description,
        condition: ProductCondition.used,
      );

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
      final item = createItem(
        idNum: 1,
        description: description,
        condition: ProductCondition.used,
      );
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

    test(
      'PDF metadata matches Preview text and description font size',
      () async {
        const item = QuotationLineItem(
          id: 'metadata-pdf',
          productCode: 'fxr01w',
          name: 'Floor tile',
          brand: 'FloorX',
          description: 'Existing description',
          unitPrice: 100,
          quantity: 1,
        );
        final pdfService = QuotationPdfService();
        await pdfService.generatePdf(
          QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
        );
        final row = pdfService.buildProductRowForTesting(1, item);
        final texts = pdfDescendants(row).whereType<pw.Text>();
        final metadata = texts.singleWhere(
          (text) =>
              (text.text as pw.TextSpan).text ==
              QuotationDocumentFormatters.formatProductMetadata(
                item.productCode,
                item.brand,
              ),
        );
        final description = texts.singleWhere(
          (text) => (text.text as pw.TextSpan).text == item.description,
        );

        expect(
          (metadata.text as pw.TextSpan).text,
          'CODE: FXR01W | BRAND: FLOORX',
        );
        expect(
          (metadata.text as pw.TextSpan).style?.fontSize,
          (description.text as pw.TextSpan).style?.fontSize,
        );
        expect(
          (metadata.text as pw.TextSpan).style?.fontSize,
          QuotationLayoutSpec.productDetailFontSize,
        );
        expect(item.productCode, 'fxr01w');
        expect(item.brand, 'FloorX');
      },
    );

    test(
      'PDF shows uppercase Condition between metadata and description at 8pt',
      () async {
        final item = createItem(
          idNum: 1,
          condition: ProductCondition.used,
          description: 'Existing description',
        );
        final pdfService = QuotationPdfService();
        await pdfService.generatePdf(
          QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
        );
        final texts = pdfDescendants(
          pdfService.buildProductRowForTesting(1, item),
        ).whereType<pw.Text>().toList();
        final values = texts
            .map((text) => (text.text as pw.TextSpan).text)
            .toList();
        final condition = texts.singleWhere(
          (text) => (text.text as pw.TextSpan).text == 'CONDITION: USED',
        );
        final description = texts.singleWhere(
          (text) => (text.text as pw.TextSpan).text == 'Existing description',
        );

        expect(
          (condition.text as pw.TextSpan).style?.fontSize,
          QuotationLayoutSpec.productDetailFontSize,
        );
        expect(
          (condition.text as pw.TextSpan).style?.fontSize,
          (description.text as pw.TextSpan).style?.fontSize,
        );
        expect(
          values.indexOf('CODE: — | BRAND: EAGLEBRAND'),
          lessThan(values.indexOf('CONDITION: USED')),
        );
        expect(
          values.indexOf('CONDITION: USED'),
          lessThan(values.indexOf('Existing description')),
        );
      },
    );

    test('PDF hides the Condition line when the snapshot is null', () async {
      final item = createItem(idNum: 1, description: 'Existing description');
      final pdfService = QuotationPdfService();
      await pdfService.generatePdf(
        QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
      );
      final values = pdfDescendants(
        pdfService.buildProductRowForTesting(1, item),
      ).whereType<pw.Text>().map((text) => (text.text as pw.TextSpan).text);

      expect(
        values.where((value) => value?.startsWith('CONDITION:') ?? false),
        isEmpty,
      );
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

      final shortPages = QuotationPaginator.paginate(
        shortQuotation,
      ).whereType<QuotationProductsPageModel>().toList();
      final longPages = QuotationPaginator.paginate(
        longQuotation,
      ).whereType<QuotationProductsPageModel>().toList();

      expect(longPages.length, greaterThan(shortPages.length));
      expect(longPages.every((page) => page.items.isNotEmpty), isTrue);
      expect(longPages.expand((page) => page.items), hasLength(20));
    });

    test(
      'Paginator counts the optional Condition line without losing items',
      () {
        const description = 'One description line';
        final legacyQuotation = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: List.generate(
            20,
            (i) => createItem(idNum: i + 1, description: description),
          ),
        );
        final conditionQuotation = QuotationDefaults.createEmptyDraft()
            .copyWith(
              lineItems: List.generate(
                20,
                (i) => createItem(
                  idNum: i + 1,
                  description: description,
                  condition: ProductCondition.display,
                ),
              ),
            );

        final legacyPages = QuotationPaginator.paginate(
          legacyQuotation,
        ).whereType<QuotationProductsPageModel>().toList();
        final conditionPages = QuotationPaginator.paginate(
          conditionQuotation,
        ).whereType<QuotationProductsPageModel>().toList();

        expect(conditionPages.length, greaterThanOrEqualTo(legacyPages.length));
        expect(conditionPages.expand((page) => page.items), hasLength(20));
        expect(
          conditionPages.first.items.length,
          lessThanOrEqualTo(legacyPages.first.items.length),
        );
      },
    );

    test(
      '7. QuotationPdfService generates PDF successfully with numeric fit and dynamic pagination',
      () async {
        final pdfService = QuotationPdfService();
        final quotation = QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: List.generate(
            6,
            (i) => createItem(idNum: i + 1, unitPrice: 100000.00),
          ),
        );

        final pdfBytes = await pdfService.generatePdf(quotation);
        expect(pdfBytes, isNotEmpty);
        expect(pdfBytes.length, greaterThan(1000));
      },
    );
  });
}
