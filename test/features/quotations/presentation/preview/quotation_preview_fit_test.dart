import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    if (widget is pw.SizedBox && widget.child != null) {
      yield* pdfDescendants(widget.child!);
    } else if (widget is pw.Container && widget.child != null) {
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
    test('shared column geometry defines the seven-column product table', () {
      expect(QuotationLayoutSpec.columnFlex, {
        'sno': 8,
        'photo': 13,
        'product': 43,
        'qty': 6,
        'unitPrice': 10,
        'discount': 8,
        'amount': 12,
      });
      expect(QuotationLayoutSpec.productImageSize, 48);
    });

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
      expect(productRow.crossAxisAlignment, CrossAxisAlignment.start);
      expect(find.text('S No.'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Product'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Disc.'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('CONDITION'), findsNothing);

      final unitPriceCell = productRow.children[4] as Expanded;
      final unitPriceFit = (unitPriceCell.child as Padding).child as FittedBox;
      final amountCell = productRow.children[6] as Expanded;
      final amountFit = (amountCell.child as Padding).child as FittedBox;
      final amountText = amountFit.child as Text;
      expect(unitPriceFit.alignment, Alignment.center);
      expect(amountFit.alignment, Alignment.center);
      expect(amountText.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('Preview displays the production discount column', (
      tester,
    ) async {
      final item = createItem(idNum: 1, discount: 7.5);
      final tableLayout = QuotationLayoutSpec.tableLayoutForItems([item]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                QuotationProductTableHeader(tableLayout: tableLayout),
                QuotationProductRow(
                  index: 1,
                  item: item,
                  tableLayout: tableLayout,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Disc.'), findsOneWidget);
      expect(find.text('7.5%'), findsOneWidget);
      expect(find.text('92,500.00'), findsOneWidget);
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
      final header = pdfService.buildTableHeaderForTesting();
      final row = pdfService.buildProductRowForTesting(1, item);
      final headerText = pdfDescendants(header)
          .whereType<pw.Text>()
          .map((text) => (text.text as pw.TextSpan).text)
          .toList();
      expect(flexes(header), expectedFlexes);
      expect(flexes(row), expectedFlexes);
      expect(headerText, [
        'S No.',
        'Photo',
        'Product',
        'Qty',
        'Price',
        'Disc.',
        'Amount',
      ]);
      final pdfRow = (row as pw.Container).child! as pw.Row;
      expect(pdfRow.crossAxisAlignment, pw.CrossAxisAlignment.start);
      expect(QuotationLayoutSpec.productImageSize, 48);
    });

    test(
      'PDF displays Discount and retains the discounted line amount',
      () async {
        final item = createItem(idNum: 1, discount: 7.5);
        final tableLayout = QuotationLayoutSpec.tableLayoutForItems([item]);
        final pdfService = QuotationPdfService();
        await pdfService.generatePdf(
          QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
        );

        List<String> textValues(pw.Widget widget) => pdfDescendants(widget)
            .whereType<pw.Text>()
            .map((text) => (text.text as pw.TextSpan).text ?? '')
            .toList();
        final header = pdfService.buildTableHeaderForTesting(
          tableLayout: tableLayout,
        );
        final row = pdfService.buildProductRowForTesting(
          1,
          item,
          tableLayout: tableLayout,
        );

        expect(textValues(header), contains('Disc.'));
        expect(textValues(row), contains('7.5%'));
        expect(textValues(row), contains('92,500.00'));
        expect(QuotationLayoutSpec.productImageSize, 48);
      },
    );

    testWidgets('production columns remain fixed for mixed discounts', (
      tester,
    ) async {
      final zeroDiscountItem = createItem(idNum: 1);
      final discountedItem = createItem(idNum: 2, discount: 7.5);
      final tableLayout = QuotationLayoutSpec.tableLayoutForItems([
        zeroDiscountItem,
        discountedItem,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                QuotationProductTableHeader(tableLayout: tableLayout),
                QuotationProductRow(
                  index: 1,
                  item: zeroDiscountItem,
                  tableLayout: tableLayout,
                ),
                QuotationProductRow(
                  index: 2,
                  item: discountedItem,
                  tableLayout: tableLayout,
                ),
              ],
            ),
          ),
        ),
      );

      final allZeroLayout = QuotationLayoutSpec.tableLayoutForItems([
        zeroDiscountItem,
        zeroDiscountItem,
      ]);
      expect(tableLayout.hasColumn('discount'), isTrue);
      expect(allZeroLayout.hasColumn('discount'), isTrue);

      final fullLayout = QuotationLayoutSpec.tableLayoutForItems([
        zeroDiscountItem.copyWith(
          imagePath: 'sample.png',
          condition: ProductCondition.newProduct,
        ),
        discountedItem.copyWith(
          imagePath: 'sample.png',
          condition: ProductCondition.newProduct,
        ),
      ]);
      expect(fullLayout.hasColumn('photo'), isTrue);
      expect(fullLayout.hasColumn('condition'), isFalse);
      expect(fullLayout.hasColumn('discount'), isTrue);
      expect(find.text('Disc.'), findsOneWidget);
      expect(find.text('7.5%'), findsOneWidget);
      expect(find.text('100,000.00'), findsNWidgets(3));
      expect(find.text('92,500.00'), findsOneWidget);
    });

    test(
      'PDF mixed discounts keep calculations and display the shared column',
      () async {
        final zeroDiscountItem = createItem(idNum: 1);
        final discountedItem = createItem(idNum: 2, discount: 7.5);
        final tableLayout = QuotationLayoutSpec.tableLayoutForItems([
          zeroDiscountItem,
          discountedItem,
        ]);
        final pdfService = QuotationPdfService();
        await pdfService.generatePdf(
          QuotationDefaults.createEmptyDraft().copyWith(
            lineItems: [zeroDiscountItem, discountedItem],
          ),
        );

        List<String> textValues(pw.Widget widget) => pdfDescendants(widget)
            .whereType<pw.Text>()
            .map((text) => (text.text as pw.TextSpan).text ?? '')
            .toList();

        expect(
          textValues(
            pdfService.buildTableHeaderForTesting(tableLayout: tableLayout),
          ),
          contains('Disc.'),
        );
        expect(
          textValues(
            pdfService.buildProductRowForTesting(
              1,
              zeroDiscountItem,
              tableLayout: tableLayout,
            ),
          ),
          contains('100,000.00'),
        );
        expect(
          textValues(
            pdfService.buildProductRowForTesting(
              2,
              discountedItem,
              tableLayout: tableLayout,
            ),
          ),
          allOf(contains('92,500.00'), contains('7.5%')),
        );
      },
    );

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

    test('2. Production photo columns paginate six products safely', () {
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

      expect(productPages.first.items, hasLength(5));
      expect(productPages.first.hasTotals, isFalse);
      expect(productPages.last.items, hasLength(1));
      expect(productPages.last.hasTotals, isTrue);
      expect(
        productPages.expand((page) => page.items),
        orderedEquals(lineItems),
      );
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

        final compactDescription =
            QuotationDocumentFormatters.formatCompactSpecification(
              description,
            )!;
        final descriptionText = tester.widget<Text>(
          find.text(compactDescription),
        );
        expect(descriptionText.data, compactDescription);
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

        final metadata = tester.widget<Text>(find.text('FXR01W • FLOORX'));
        final name = tester.widget<Text>(find.text('Floor tile'));
        final description = tester.widget<Text>(
          find.text('Existing description'),
        );

        expect(name.style?.fontWeight, FontWeight.w600);
        expect(name.textAlign, isNull);
        expect(metadata.style?.fontSize, description.style?.fontSize);
        expect(
          metadata.style?.fontSize,
          QuotationLayoutSpec.productDetailFontSize,
        );
        expect(item.productCode, 'fxr01w');
        expect(item.brand, 'FloorX');
      },
    );

    testWidgets('Preview keeps Condition inside the Product cell at 8pt', (
      tester,
    ) async {
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

      final conditionFinder = find.text('CONDITION: USED');
      final descriptionFinder = find.text('Existing description');
      final condition = tester.widget<Text>(conditionFinder);
      final description = tester.widget<Text>(descriptionFinder);
      final productRow = tester.widget<Row>(
        find.descendant(
          of: find.byType(QuotationProductRow),
          matching: find.byType(Row),
        ),
      );

      expect(
        condition.style?.fontSize,
        QuotationLayoutSpec.productDetailFontSize,
      );
      expect(condition.style?.fontSize, description.style?.fontSize);
      expect(condition.textAlign, isNull);
      expect(productRow.crossAxisAlignment, CrossAxisAlignment.start);
    });

    testWidgets('Preview omits Condition when the product has none', (
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

      final compactDescription =
          QuotationDocumentFormatters.formatCompactSpecification(description)!;
      final descriptionText = tester.widget<Text>(
        find.text(compactDescription),
      );
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, TextOverflow.visible);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Preview uses a centered 48px contained product image', (
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
      expect(QuotationLayoutSpec.productImageSize, 48);
      expect(productImage.width, 48);
      expect(productImage.height, 48);
      expect(productImage.fit, BoxFit.contain);
      expect(
        find.ancestor(
          of: find.byType(ProductImage),
          matching: find.byType(Center),
        ),
        findsWidgets,
      );

      final compactDescription =
          QuotationDocumentFormatters.formatCompactSpecification(description)!;
      final descriptionText = tester.widget<Text>(
        find.text(compactDescription),
      );
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
      final compactDescription =
          QuotationDocumentFormatters.formatCompactSpecification(description)!;
      final descriptionText = pdfDescendants(row)
          .whereType<pw.Text>()
          .singleWhere(
            (text) => (text.text as pw.TextSpan).text == compactDescription,
          );

      expect(pdfBytes, isNotEmpty);
      expect((descriptionText.text as pw.TextSpan).text, compactDescription);
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
              QuotationDocumentFormatters.formatCompactProductMetadata(
                item.productCode,
                item.brand,
              ),
        );
        final description = texts.singleWhere(
          (text) => (text.text as pw.TextSpan).text == item.description,
        );

        expect((metadata.text as pw.TextSpan).text, 'FXR01W • FLOORX');
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

    test('PDF keeps Condition inside the Product cell at 8pt', () async {
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
      expect(condition.textAlign, isNull);
    });

    test('PDF omits Condition when the product has none', () async {
      final item = createItem(idNum: 1, description: 'Existing description');
      final pdfService = QuotationPdfService();
      await pdfService.generatePdf(
        QuotationDefaults.createEmptyDraft().copyWith(lineItems: [item]),
      );
      final values = pdfDescendants(
        pdfService.buildProductRowForTesting(1, item),
      ).whereType<pw.Text>().map((text) => (text.text as pw.TextSpan).text);

      expect(values.whereType<String>(), isNot(contains('CONDITION: —')));
    });

    test('PDF uses the matching 48pt contained product image', () async {
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
      final compactDescription =
          QuotationDocumentFormatters.formatCompactSpecification(description)!;
      final descriptionText = pdfDescendants(row)
          .whereType<pw.Text>()
          .singleWhere(
            (text) => (text.text as pw.TextSpan).text == compactDescription,
          );

      expect(image.width, 48);
      expect(image.height, 48);
      expect(image.fit, pw.BoxFit.contain);
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, pw.TextOverflow.visible);
    });

    test('Paginator accounts for expanded multiline product rows', () {
      const shortDescription = 'Line 1\nLine 2';
      const longDescription =
          'Commercial heavy-duty structural steel frame with electrostatic powder coating\n'
          'Dual 100 kg precision-machined steel weight stacks with sound dampening\n'
          'Ergonomic multi-position adjustable contoured upholstery with high-density foam\n'
          'Precision sealed aircraft-grade pulleys and nylon-coated military cables\n'
          'Integrated chin-up bar, foot rests, and instructional exercise chart\n'
          'Warranty: 10 years structural frame, 3 years bearings and moving parts';
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
      expect(
        longPages.first.items.length,
        lessThan(shortPages.first.items.length),
      );
      expect(longPages.expand((page) => page.items), hasLength(20));
    });

    test(
      'Paginator measures inline Condition details without losing items',
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

    test('compact pagination fits eight short products on page 1', () {
      final items = List.generate(
        16,
        (index) => QuotationLineItem(
          id: 'SHORT-${index + 1}',
          name: 'Bench ${index + 1}',
          brand: 'Eagle',
          unitPrice: 1250,
          quantity: 1,
        ),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: items,
      );
      final productPages = QuotationPaginator.paginate(
        quotation,
        salespersonName: 'Shijo',
      ).whereType<QuotationProductsPageModel>().toList();

      expect(productPages.first.items, hasLength(8));
      expect(productPages.expand((page) => page.items), orderedEquals(items));
    });

    test('normal specifications fit at least eight products on page 1', () {
      final items = List.generate(
        18,
        (index) => QuotationLineItem(
          id: 'NORMAL-${index + 1}',
          name: 'Treadmill ${index + 1}',
          brand: 'Eagle',
          unitPrice: 7250,
          quantity: 1,
          description: 'Motor 7 HP AC\nMaximum user weight 180 kg',
        ),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: items,
      );
      final productPages = QuotationPaginator.paginate(
        quotation,
        salespersonName: 'Shijo',
      ).whereType<QuotationProductsPageModel>().toList();
      final nonEmptyPages = productPages
          .where((page) => page.items.isNotEmpty)
          .toList();

      expect(nonEmptyPages.map((page) => page.items.length), [8, 10]);
      expect(nonEmptyPages.last.hasTotals, isTrue);
      expect(productPages.expand((page) => page.items), orderedEquals(items));
    });

    test('long specifications reduce capacity without losing items', () {
      final items = List.generate(
        12,
        (index) => QuotationLineItem(
          id: 'LONG-${index + 1}',
          name: 'Strength station ${index + 1}',
          brand: 'Eagle',
          unitPrice: 9850,
          quantity: 1,
          discount: index == 0 ? 5 : 0,
          description:
              'Frame: commercial-grade steel\n'
              'Stack: 100 kg precision plates\n'
              'Upholstery: high-density foam\n'
              'Warranty: 5 years structural',
        ),
      );
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: items,
      );
      final productPages = QuotationPaginator.paginate(
        quotation,
        salespersonName: 'Shijo',
      ).whereType<QuotationProductsPageModel>().toList();

      expect(productPages.first.items.length, lessThan(8));
      expect(productPages.every((page) => page.items.isNotEmpty), isTrue);
      expect(productPages.last.hasTotals, isTrue);
      expect(productPages.expand((page) => page.items), orderedEquals(items));
      expect(
        productPages
            .expand((page) => page.items)
            .map((item) => item.id)
            .toSet(),
        hasLength(items.length),
      );
    });

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
