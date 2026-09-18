import 'dart:typed_data';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/utils/pdf_share_helper.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/previous_quotations_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/previous/quotation_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

class _FakeQuotationRepository implements QuotationRepository {
  _FakeQuotationRepository({required this.summary, required this.full});

  final Quotation summary;
  final Quotation full;
  Quotation? imageLoadInput;

  @override
  Future<List<Quotation>> getAllQuotations() async => [summary];

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async {
    imageLoadInput = quotation;
    return full;
  }

  @override
  Future<void> deleteQuotation(String id) async {}

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) async =>
      sourceQuotation;

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) async => null;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async => quotation;
}

void main() {
  late Quotation summary;
  late Quotation full;
  late _FakeQuotationRepository repository;

  setUp(() {
    ServiceLocator.resetForTesting();
    summary = QuotationDefaults.createEmptyDraft(
      salespersonId: 'salesperson-id',
    ).copyWith(id: 'quotation-id', quotationNumber: 'QT/123');
    full = summary.copyWith(
      customerNotes: 'Full quotation with images',
      lineItems: [
        QuotationLineItem(
          id: 'line-item-id',
          productId: 'product-id',
          name: 'Product with image',
          brand: 'Brand',
          unitPrice: 100,
          quantity: 1,
          imageBytes: Uint8List.fromList([9, 8, 7]),
        ),
      ],
    );
    repository = _FakeQuotationRepository(summary: summary, full: full);
    ServiceLocator().mockQuotationRepository = repository;
  });

  tearDown(ServiceLocator.resetForTesting);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Future<Uint8List> Function(Quotation) generator,
    required PdfShareHelper shareHelper,
    required Future<void> Function({
      required List<int> bytes,
      required String filename,
    })
    downloader,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PreviousQuotationsScreen(
          pdfGenerator: generator,
          pdfShareHelper: shareHelper,
          pdfDownloader: downloader,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectShare(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share PDF'));
    await tester.pumpAndSettle();
  }

  testWidgets('Share loads full quotation, generates its PDF, and shares it', (
    tester,
  ) async {
    final generatedBytes = Uint8List.fromList([1, 2, 3]);
    Quotation? generatedQuotation;
    Uint8List? sharedBytes;
    String? sharedFilename;
    var downloadCalls = 0;

    await pumpScreen(
      tester,
      generator: (quotation) async {
        generatedQuotation = quotation;
        return generatedBytes;
      },
      shareHelper: PdfShareHelper(
        share: (params) async {
          sharedBytes = await params.files!.single.readAsBytes();
          sharedFilename = params.fileNameOverrides!.single;
          return const ShareResult('shared', ShareResultStatus.success);
        },
      ),
      downloader: ({required bytes, required filename}) async {
        downloadCalls++;
      },
    );

    await selectShare(tester);

    expect(repository.imageLoadInput, same(summary));
    expect(generatedQuotation, same(full));
    expect(sharedBytes, generatedBytes);
    expect(sharedFilename, 'QT_123.pdf');
    expect(downloadCalls, 0);
  });

  testWidgets('unsupported sharing downloads the generated PDF instead', (
    tester,
  ) async {
    final generatedBytes = Uint8List.fromList([4, 5, 6]);
    List<int>? downloadedBytes;
    String? downloadedFilename;

    await pumpScreen(
      tester,
      generator: (_) async => generatedBytes,
      shareHelper: PdfShareHelper(
        share: (_) async => throw Exception('Sharing unsupported'),
      ),
      downloader: ({required bytes, required filename}) async {
        downloadedBytes = bytes;
        downloadedFilename = filename;
      },
    );

    await selectShare(tester);

    expect(downloadedBytes, generatedBytes);
    expect(downloadedFilename, 'QT_123.pdf');
    expect(
      find.text(
        "File sharing isn't supported in this browser. "
        'The PDF was downloaded instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('share failure shows an error without crashing', (tester) async {
    var shareCalls = 0;
    var downloadCalls = 0;

    await pumpScreen(
      tester,
      generator: (_) async => throw Exception('PDF generation failed'),
      shareHelper: PdfShareHelper(
        share: (_) async {
          shareCalls++;
          return const ShareResult('shared', ShareResultStatus.success);
        },
      ),
      downloader: ({required bytes, required filename}) async {
        downloadCalls++;
      },
    );

    await selectShare(tester);

    expect(shareCalls, 0);
    expect(downloadCalls, 0);
    expect(
      find.text('Failed to share quotation PDF. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(PreviousQuotationsScreen), findsOneWidget);
  });

  testWidgets(
    'View, Edit, Duplicate, and Delete callbacks remain independent',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var viewCalls = 0;
      var editCalls = 0;
      var duplicateCalls = 0;
      var deleteCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationListView(
              quotations: [summary],
              onView: (_) => viewCalls++,
              onEdit: (_) => editCalls++,
              onDuplicate: (_) => duplicateCalls++,
              onShare: (_) {},
              onDelete: (_) => deleteCalls++,
              onCreate: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('View'));
      await tester.tap(find.text('Edit'));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(viewCalls, 1);
      expect(editCalls, 1);
      expect(duplicateCalls, 1);
      expect(deleteCalls, 1);
    },
  );
}
