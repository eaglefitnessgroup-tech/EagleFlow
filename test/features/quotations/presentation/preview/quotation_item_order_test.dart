import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_row.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_products_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

Iterable<pw.Widget> _pdfDescendants(pw.Widget widget) sync* {
  yield widget;
  if (widget is pw.SizedBox && widget.child != null) {
    yield* _pdfDescendants(widget.child!);
  } else if (widget is pw.Flexible && widget.child != null) {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  QuotationLineItem item(String id, String name) => QuotationLineItem(
    id: id,
    productCode: id.toUpperCase(),
    name: name,
    brand: 'Brand',
    unitPrice: 10,
    quantity: 1,
  );

  Quotation reorderedQuotation() =>
      QuotationDefaults.createEmptyDraft().copyWith(
        lineItems: [
          item('c', 'Third selected first'),
          item('a', 'First selected second'),
          item('b', 'Second selected third'),
        ],
      );

  test('preview paginator preserves reordered item sequence', () {
    final quotation = reorderedQuotation();

    final productItems = QuotationPaginator.paginate(quotation)
        .whereType<QuotationProductsPageModel>()
        .expand((page) => page.items)
        .toList();

    expect(productItems.map((item) => item.id), ['c', 'a', 'b']);
  });

  testWidgets('preview rows use reordered sequence and sequential S No.', (
    tester,
  ) async {
    final quotation = reorderedQuotation();
    final model = QuotationProductsPageModel(
      items: quotation.lineItems,
      hasCover: false,
      hasTotals: false,
      isLastPage: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotationProductsPage(
            quotation: quotation,
            model: model,
            startIndex: 0,
          ),
        ),
      ),
    );

    final rows = tester
        .widgetList<QuotationProductRow>(find.byType(QuotationProductRow))
        .toList();
    expect(rows.map((row) => row.item.id), ['c', 'a', 'b']);
    expect(rows.map((row) => row.index), [1, 2, 3]);
  });

  test('PDF rows retain reordered products and sequential S No.', () async {
    final quotation = reorderedQuotation();
    final service = QuotationPdfService();

    final pdfBytes = await service.generatePdf(quotation);
    expect(pdfBytes, isNotEmpty);

    final rows = quotation.lineItems.indexed.map((entry) {
      final row = service.buildProductRowForTesting(entry.$1 + 1, entry.$2);
      return _pdfDescendants(row)
          .whereType<pw.Text>()
          .map((text) => (text.text as pw.TextSpan).text)
          .whereType<String>()
          .toList();
    }).toList();

    expect(rows[0], containsAll(['1', 'Third selected first']));
    expect(rows[1], containsAll(['2', 'First selected second']));
    expect(rows[2], containsAll(['3', 'Second selected third']));
  });
}
