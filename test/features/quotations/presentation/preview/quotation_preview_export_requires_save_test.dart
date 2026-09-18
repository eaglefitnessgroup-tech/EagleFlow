import 'dart:typed_data';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/utils/pdf_share_helper.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

const _saveFirstMessage =
    'Please save the quotation first to generate a quotation number.';

class _AssigningQuotationRepository implements QuotationRepository {
  Quotation? savedInput;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    savedInput = quotation;
    return quotation.copyWith(id: 'saved-id', quotationNumber: 'QT/2026:01');
  }

  @override
  Future<void> deleteQuotation(String id) => throw UnimplementedError();

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) =>
      throw UnimplementedError();

  @override
  Future<List<Quotation>> getAllQuotations() => throw UnimplementedError();

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) =>
      throw UnimplementedError();

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) =>
      throw UnimplementedError();
}

class _ActionCalls {
  int pdfGenerations = 0;
  int pdfSaves = 0;
  int excelGenerations = 0;
  int downloads = 0;
  int prints = 0;
  int shares = 0;
  final filenames = <String>[];

  int get total =>
      pdfGenerations +
      pdfSaves +
      excelGenerations +
      downloads +
      prints +
      shares;
}

void main() {
  late _AssigningQuotationRepository repository;
  late QuotationController controller;
  late _ActionCalls calls;

  setUp(() {
    ServiceLocator.resetForTesting();
    repository = _AssigningQuotationRepository();
    ServiceLocator().mockQuotationRepository = repository;
    final user = AppUser(
      id: 'salesperson-id',
      name: 'Sales Person',
      username: 'sales.person',
      passwordHash: '',
      role: UserRole.sales,
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );
    ServiceLocator().authController.setCurrentUserForTesting(user);
    controller = QuotationController(
      QuotationDefaults.createEmptyDraft(salespersonId: user.id),
    );
    calls = _ActionCalls();
  });

  tearDown(ServiceLocator.resetForTesting);

  Future<void> pumpPreview(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: controller),
          builder: (_) => QuotationPreviewScreen(
            excelGenerator: (quotation, {salespersonName}) {
              calls.excelGenerations++;
              return const [7, 8, 9];
            },
            fileDownloader: ({required bytes, required filename}) async {
              calls.downloads++;
              calls.filenames.add(filename);
            },
            pdfGenerator: (quotation) async {
              calls.pdfGenerations++;
              return Uint8List.fromList([1, 2, 3]);
            },
            pdfSaver: (bytes, filename) async {
              calls.pdfSaves++;
              calls.filenames.add(filename);
              return 'saved';
            },
            pdfPrinter: (bytes, filename) async {
              calls.prints++;
              calls.filenames.add(filename);
            },
            pdfShareHelper: PdfShareHelper(
              share: (params) async {
                calls.shares++;
                calls.filenames.add(params.fileNameOverrides!.single);
                return const ShareResult('shared', ShareResultStatus.success);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectExportAction(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> expectBlocked(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    await pumpPreview(tester);
    await action();

    expect(calls.total, 0);
    expect(find.text(_saveFirstMessage), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  }

  testWidgets('blank quotation number blocks Download PDF', (tester) async {
    await expectBlocked(tester, () async {
      await tester.tap(find.byTooltip('Download PDF'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('blank quotation number blocks Export to PDF', (tester) async {
    await expectBlocked(
      tester,
      () => selectExportAction(tester, 'Export to PDF'),
    );
  });

  testWidgets('blank quotation number blocks Excel export', (tester) async {
    await expectBlocked(
      tester,
      () => selectExportAction(tester, 'Export to Excel'),
    );
  });

  testWidgets('blank quotation number blocks Print', (tester) async {
    await expectBlocked(tester, () => selectExportAction(tester, 'Print'));
  });

  testWidgets('blank quotation number blocks Share PDF', (tester) async {
    await expectBlocked(tester, () => selectExportAction(tester, 'Share PDF'));
  });

  testWidgets(
    'Save assigns number and all actions use sanitized saved filenames',
    (tester) async {
      await pumpPreview(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedInput?.quotationNumber, isEmpty);
      expect(controller.quotation.id, 'saved-id');
      expect(controller.quotation.quotationNumber, 'QT/2026:01');

      await tester.tap(find.byTooltip('Download PDF'));
      await tester.pumpAndSettle();
      await selectExportAction(tester, 'Export to PDF');
      await selectExportAction(tester, 'Export to Excel');
      await selectExportAction(tester, 'Print');
      await selectExportAction(tester, 'Share PDF');

      expect(calls.pdfGenerations, 4);
      expect(calls.pdfSaves, 2);
      expect(calls.excelGenerations, 1);
      expect(calls.downloads, 1);
      expect(calls.prints, 1);
      expect(calls.shares, 1);
      expect(
        calls.filenames,
        everyElement(anyOf('QT_2026_01.pdf', 'QT_2026_01.xlsx')),
      );
      expect(
        calls.filenames.where((name) => name.endsWith('.pdf')),
        hasLength(4),
      );
      expect(
        calls.filenames.where((name) => name.endsWith('.xlsx')),
        hasLength(1),
      );
      expect(find.text(_saveFirstMessage), findsNothing);
    },
  );
}
