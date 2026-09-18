import 'dart:typed_data';

import 'package:eagleflow/core/utils/pdf_share_helper.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester, {
    required Future<Uint8List> Function(Quotation) generator,
    required Future<String?> Function(Uint8List, String) saver,
    required PdfShareHelper shareHelper,
  }) async {
    final quotation = QuotationDefaults.createEmptyDraft().copyWith(
      id: 'quotation-id',
      quotationNumber: 'QT/123',
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: QuotationController(quotation)),
          builder: (_) => QuotationPreviewScreen(
            pdfGenerator: generator,
            pdfSaver: saver,
            pdfShareHelper: shareHelper,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Download PDF directly generates and saves the current PDF', (
    tester,
  ) async {
    final generatedBytes = Uint8List.fromList([1, 2, 3, 4]);
    Quotation? generatedQuotation;
    Uint8List? savedBytes;
    String? savedFilename;
    var shareCalls = 0;

    await pumpPreview(
      tester,
      generator: (quotation) async {
        generatedQuotation = quotation;
        return generatedBytes;
      },
      saver: (bytes, filename) async {
        savedBytes = bytes;
        savedFilename = filename;
        return 'Downloaded to browser';
      },
      shareHelper: PdfShareHelper(
        share: (_) async {
          shareCalls++;
          return ShareResult.unavailable;
        },
      ),
    );

    await tester.tap(find.byTooltip('Download PDF'));
    await tester.pumpAndSettle();

    expect(generatedQuotation?.id, 'quotation-id');
    expect(generatedQuotation?.quotationNumber, 'QT/123');
    expect(savedBytes, generatedBytes);
    expect(savedFilename, 'QT_123.pdf');
    expect(shareCalls, 0);
    expect(find.byType(QuotationPreviewScreen), findsOneWidget);
    expect(find.textContaining('Saved to'), findsNothing);
  });

  testWidgets('Download PDF shows an error only when generation fails', (
    tester,
  ) async {
    var saveCalls = 0;

    await pumpPreview(
      tester,
      generator: (_) async => throw Exception('generation failed'),
      saver: (_, _) async {
        saveCalls++;
        return null;
      },
      shareHelper: PdfShareHelper(
        share: (_) async => ShareResult.unavailable,
      ),
    );

    await tester.tap(find.byTooltip('Download PDF'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.textContaining('Error generating PDF'), findsOneWidget);
    expect(find.byType(QuotationPreviewScreen), findsOneWidget);
  });
}
