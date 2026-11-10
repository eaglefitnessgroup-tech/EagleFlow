import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_numeric_fit_helper.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_row.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_table_header.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_totals_block.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_document_formatters.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_document_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'quotation_test_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const item = QuotationLineItem(
    id: 'typography-item',
    productCode: 'EF-01',
    name: 'Premium training bench',
    brand: 'Eagle',
    description: 'Compact specification text',
    unitPrice: 1250,
    quantity: 1,
  );
  final quotation = QuotationDefaults.createEmptyDraft().copyWith(
    lineItems: const [item],
  );

  setUpAll(loadQuotationTestFonts);

  test('document theme uses the approved IBM Plex weight hierarchy', () {
    final styles = [
      QuotationDocumentTheme.h1,
      QuotationDocumentTheme.h2,
      QuotationDocumentTheme.h3,
      QuotationDocumentTheme.body,
      QuotationDocumentTheme.bodyBold,
      QuotationDocumentTheme.small,
      QuotationDocumentTheme.smallBold,
    ];

    expect(styles.map((style) => style.fontFamily).toSet(), {
      QuotationDocumentTheme.fontFamily,
    });
    expect(QuotationDocumentTheme.body.fontWeight, FontWeight.w400);
    expect(QuotationDocumentTheme.small.fontWeight, FontWeight.w400);
    expect(QuotationDocumentTheme.bodyBold.fontWeight, FontWeight.w500);
    expect(QuotationDocumentTheme.smallBold.fontWeight, FontWeight.w500);
    expect(QuotationDocumentTheme.h1.fontWeight, FontWeight.w500);
    expect(QuotationDocumentTheme.h2.fontWeight, FontWeight.w500);
    expect(QuotationDocumentTheme.h3.fontWeight, FontWeight.w500);
    expect(
      QuotationNumericFitHelper.previewStyle().fontWeight,
      FontWeight.w500,
    );
  });

  testWidgets('preview applies regular and medium intentionally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const QuotationProductTableHeader(),
              const QuotationProductRow(index: 1, item: item),
              QuotationTotalsBlock(quotation: quotation),
            ],
          ),
        ),
      ),
    );

    final metadataText =
        QuotationDocumentFormatters.formatCompactProductMetadata(
          item.productCode,
          item.brand,
        );
    final productName = tester.widget<Text>(find.text(item.name));
    final metadata = tester.widget<Text>(find.text(metadataText));
    final specification = tester.widget<Text>(
      find.text('Compact specification text'),
    );
    final grandTotal = tester.widget<Text>(find.text('Grand Total'));
    final amountInWords = tester.widget<Text>(find.text('Amount in Words'));

    expect(productName.style?.fontFamily, 'IBM Plex Sans Condensed');
    expect(productName.style?.fontWeight, FontWeight.w500);
    expect(metadata.style?.fontWeight, FontWeight.w400);
    expect(specification.style?.fontWeight, FontWeight.w400);
    expect(grandTotal.style?.fontWeight, FontWeight.w500);
    expect(amountInWords.style?.fontWeight, FontWeight.w500);
    expect(find.text('AMOUNT IN WORDS'), findsNothing);
  });

  test('exported PDF embeds and uses the matching IBM Plex weights', () async {
    final service = QuotationPdfService();
    final bytes = await service.generatePdf(quotation);
    final rowTexts = _pdfDescendants(
      service.buildProductRowForTesting(1, item),
    ).whereType<pw.Text>().toList();
    final totalsTexts = _pdfDescendants(
      service.buildTotalsBlockForTesting(quotation),
    ).whereType<pw.Text>().toList();

    pw.Text rowText(String value) => rowTexts.singleWhere(
      (text) => (text.text as pw.TextSpan).text == value,
    );
    pw.Text totalsText(String value) => totalsTexts.singleWhere(
      (text) => (text.text as pw.TextSpan).text == value,
    );
    String fontName(pw.Text text) =>
        (text.text as pw.TextSpan).style!.font!.fontName;

    expect(bytes, isNotEmpty);
    expect(fontName(rowText(item.name)), contains('IBMPlexSansCond-Medium'));
    expect(
      fontName(
        rowText(
          QuotationDocumentFormatters.formatCompactProductMetadata(
            item.productCode,
            item.brand,
          ),
        ),
      ),
      contains('IBMPlexSansCond-Regular'),
    );
    expect(
      fontName(rowText('Compact specification text')),
      contains('IBMPlexSansCond-Regular'),
    );
    expect(
      fontName(totalsText('Grand Total')),
      contains('IBMPlexSansCond-Medium'),
    );
    expect(
      fontName(totalsText('Amount in Words')),
      contains('IBMPlexSansCond-Medium'),
    );
  });
}

Iterable<pw.Widget> _pdfDescendants(pw.Widget widget) sync* {
  yield widget;
  if (widget is pw.SizedBox && widget.child != null) {
    yield* _pdfDescendants(widget.child!);
  } else if (widget is pw.Container && widget.child != null) {
    yield* _pdfDescendants(widget.child!);
  } else if (widget is pw.SingleChildWidget && widget.child != null) {
    yield* _pdfDescendants(widget.child!);
  } else if (widget is pw.MultiChildWidget) {
    for (final child in widget.children) {
      yield* _pdfDescendants(child);
    }
  }
}
