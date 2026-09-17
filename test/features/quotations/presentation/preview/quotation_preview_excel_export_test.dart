import 'dart:typed_data';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppUser salesperson;

  setUp(() {
    ServiceLocator.resetForTesting();
    final now = DateTime(2026, 9, 17);
    salesperson = AppUser(
      id: 'SALES-001',
      name: 'Sam Sales',
      username: 'sam.sales',
      passwordHash: '',
      role: UserRole.sales,
      createdAt: now,
      updatedAt: now,
    );
    ServiceLocator().authController.setCurrentUserForTesting(salesperson);
  });

  tearDown(ServiceLocator.resetForTesting);

  Future<void> pumpPreview(
    WidgetTester tester, {
    QuotationExcelGenerator? excelGenerator,
    QuotationFileDownloader? fileDownloader,
    QuotationPdfGenerator? pdfGenerator,
    QuotationPdfSaver? pdfSaver,
  }) async {
    final quotation = QuotationDefaults.createEmptyDraft(
      salespersonId: salesperson.id,
    ).copyWith(quotationNumber: 'QT/2026:01');

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: QuotationController(quotation)),
          builder: (_) => QuotationPreviewScreen(
            excelGenerator: excelGenerator,
            fileDownloader: fileDownloader,
            pdfGenerator: pdfGenerator,
            pdfSaver: pdfSaver,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openExportMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Export to Excel is enabled without changing other menu actions',
    (tester) async {
      await pumpPreview(tester);
      await openExportMenu(tester);

      final excelItem = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text('Export to Excel'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );

      expect(excelItem.enabled, isTrue);
      expect(find.text('Export to Excel (Coming Soon)'), findsNothing);
      expect(find.text('Export to PDF'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
    },
  );

  testWidgets('Export to Excel generates and downloads a sanitized workbook', (
    tester,
  ) async {
    const workbookBytes = <int>[1, 2, 3, 4];
    String? generatedQuotationNumber;
    String? generatedSalespersonName;
    List<int>? downloadedBytes;
    String? downloadedFilename;
    var pdfGenerationCalls = 0;
    var pdfSaveCalls = 0;

    await pumpPreview(
      tester,
      excelGenerator: (quotation, {salespersonName}) {
        generatedQuotationNumber = quotation.quotationNumber;
        generatedSalespersonName = salespersonName;
        return workbookBytes;
      },
      fileDownloader: ({required bytes, required filename}) async {
        downloadedBytes = bytes;
        downloadedFilename = filename;
      },
      pdfGenerator: (_) async {
        pdfGenerationCalls++;
        return Uint8List(0);
      },
      pdfSaver: (_, _) async {
        pdfSaveCalls++;
        return null;
      },
    );
    await openExportMenu(tester);
    await tester.tap(find.text('Export to Excel'));
    await tester.pumpAndSettle();

    expect(generatedQuotationNumber, 'QT/2026:01');
    expect(generatedSalespersonName, 'Sam Sales');
    expect(downloadedBytes, workbookBytes);
    expect(downloadedFilename, 'QT_2026_01.xlsx');
    expect(downloadedFilename, endsWith('.xlsx'));
    expect(pdfGenerationCalls, 0);
    expect(pdfSaveCalls, 0);
  });
}
