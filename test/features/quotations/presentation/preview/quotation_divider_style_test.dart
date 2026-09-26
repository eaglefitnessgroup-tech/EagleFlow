import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_document_header.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_product_table_header.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_cover_section.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_info_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_document_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedFlutterColor = Color(0xFFE2E8F0);
  const expectedPdfColor = PdfColor.fromInt(0xFFE2E8F0);

  Finder fixedWidthDivider(Finder scope, double width) {
    return find.descendant(
      of: scope,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final constraints = widget.constraints;
        return constraints?.minWidth == width &&
            constraints?.maxWidth == width &&
            constraints?.minHeight == QuotationDocumentTheme.dividerThickness &&
            constraints?.maxHeight == QuotationDocumentTheme.dividerThickness &&
            widget.color == QuotationDocumentTheme.dividerColor;
      }),
    );
  }

  testWidgets('Preview marked lines reuse the logo/header divider style', (
    tester,
  ) async {
    final quotation = QuotationDefaults.createEmptyDraft();

    expect(QuotationDocumentTheme.dividerColor, expectedFlutterColor);
    expect(QuotationDocumentTheme.dividerThickness, 1);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuotationDocumentHeader())),
    );
    final headerDivider = tester.widget<Divider>(
      find.descendant(
        of: find.byType(QuotationDocumentHeader),
        matching: find.byType(Divider),
      ),
    );
    expect(headerDivider.color, QuotationDocumentTheme.dividerColor);
    expect(headerDivider.thickness, QuotationDocumentTheme.dividerThickness);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuotationCoverSection(quotation: quotation)),
      ),
    );
    expect(
      fixedWidthDivider(find.byType(QuotationCoverSection), 130),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuotationProductTableHeader())),
    );
    final tableHeader = tester.widget<Container>(
      find.descendant(
        of: find.byType(QuotationProductTableHeader),
        matching: find.byType(Container),
      ),
    );
    final tableBorder =
        (tableHeader.decoration as BoxDecoration).border as Border;
    expect(tableBorder.top, QuotationDocumentTheme.dividerBorderSide);
    expect(tableBorder.bottom, QuotationDocumentTheme.dividerBorderSide);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              height: 1200,
              child: QuotationInfoPage(quotation: quotation),
            ),
          ),
        ),
      ),
    );
    expect(
      fixedWidthDivider(find.byType(QuotationInfoPage), 55),
      findsOneWidget,
    );
  });

  test('PDF marked lines reuse the logo/header divider style and lengths', () {
    final service = QuotationPdfService();

    expect(service.documentDividerColorForTesting, expectedPdfColor);
    expect(service.documentDividerThicknessForTesting, 1);

    final headerDivider = service.buildDocumentDividerForTesting();
    expect(headerDivider.color, expectedPdfColor);
    expect(headerDivider.thickness, 1);
    expect(headerDivider.height, 1);

    final tableSide = service.documentDividerBorderSideForTesting();
    expect(tableSide.color, expectedPdfColor);
    expect(tableSide.width, 1);

    for (final width in [130.0, 55.0]) {
      final outer =
          service.buildFixedWidthDocumentDividerForTesting(width)
              as pw.Container;
      final inner = outer.child as pw.Container;

      expect(outer.constraints?.minWidth, width);
      expect(outer.constraints?.maxWidth, width);
      expect(outer.constraints?.minHeight, 1.5);
      expect(outer.constraints?.maxHeight, 1.5);
      expect(inner.constraints?.minWidth, width);
      expect(inner.constraints?.maxWidth, width);
      expect(inner.constraints?.minHeight, 1);
      expect(inner.constraints?.maxHeight, 1);
      expect(inner.decoration?.color, expectedPdfColor);
    }
  });
}
