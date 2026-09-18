import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../quotation_document_theme.dart';

/// Isolated helper for fitting numeric amounts (Qty, Price, Disc, Amount) up to 100,000.00
/// on a single line in both Quotation Preview and PDF export.
class QuotationNumericFitHelper {
  QuotationNumericFitHelper._();

  static const double previewNumericFontSize = 10.0;
  static const double pdfNumericFontSize = previewNumericFontSize;

  /// Returns single-line text style for preview numeric cells.
  static TextStyle previewStyle({bool bold = false}) {
    return (bold
            ? QuotationDocumentTheme.bodyBold
            : QuotationDocumentTheme.body)
        .copyWith(fontSize: previewNumericFontSize);
  }

  /// Builds a numeric cell for Flutter UI preview with single-line enforcement.
  static Widget buildPreviewCell(
    String text,
    int flex, {
    bool center = false,
    bool right = false,
    bool bold = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: center
              ? Alignment.center
              : right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: previewStyle(bold: bold),
          ),
        ),
      ),
    );
  }

  /// Builds a numeric cell for PDF export with single-line enforcement.
  static pw.Widget buildPdfCell(
    String text,
    int flex,
    pw.Font fontRegular,
    pw.Font fontSemiBold, {
    bool center = false,
    bool right = false,
    bool bold = false,
    PdfColor? color,
  }) {
    final textColor =
        color ??
        (bold
            ? const PdfColor.fromInt(0xFF0F172A)
            : const PdfColor.fromInt(0xFF334155));
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Align(
          alignment: center
              ? pw.Alignment.center
              : right
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: center
                ? pw.Alignment.center
                : right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
            child: pw.Text(
              text,
              maxLines: 1,
              tightBounds: true,
              style: pw.TextStyle(
                font: bold ? fontSemiBold : fontRegular,
                fontSize: pdfNumericFontSize,
                color: textColor,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
