import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/preview/pages/quotation_cover_section.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/quotation_bottom_action_bar.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/quotation_page_header.dart';
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

Quotation _quotation({int revisionNo = 0}) {
  return QuotationDefaults.createEmptyDraft().copyWith(
    id: revisionNo == 0 ? 'original' : 'revision-$revisionNo',
    quotationNumber: 'QT-AN-0027-26',
    baseQuotationId: revisionNo == 0 ? null : 'original',
    revisionNo: revisionNo,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('revision editor shows revision heading and save action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const QuotationPageHeader(
                quotationNumber: 'QT-AN-0027-26 / R1',
                isRevision: true,
              ),
              const Spacer(),
              QuotationBottomActionBar(
                canPreview: true,
                onPreview: () {},
                onSaveDraft: () {},
                saveLabel: 'Save Revision',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Revise Quotation'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R1'), findsOneWidget);
    expect(find.text('Save Revision'), findsOneWidget);
    expect(find.text('Save Quotation'), findsNothing);
  });

  testWidgets('preview cover uses original and revision display labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuotationCoverSection(quotation: _quotation())),
      ),
    );
    expect(find.text('QT-AN-0027-26'), findsOneWidget);
    expect(find.text('QT-AN-0027-26 / R1'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotationCoverSection(quotation: _quotation(revisionNo: 1)),
        ),
      ),
    );
    expect(find.text('QT-AN-0027-26 / R1'), findsOneWidget);
  });

  test('PDF cover uses original and revision display labels', () async {
    final service = QuotationPdfService();
    final original = _quotation();
    final revision = _quotation(revisionNo: 1);
    await service.generatePdf(original);

    List<String?> textValues(Quotation quotation) {
      return _pdfDescendants(service.buildCoverSectionForTesting(quotation))
          .whereType<pw.Text>()
          .map((text) => (text.text as pw.TextSpan).text)
          .toList();
    }

    expect(textValues(original), contains('QT-AN-0027-26'));
    expect(textValues(original), isNot(contains('QT-AN-0027-26 / R1')));
    expect(textValues(revision), contains('QT-AN-0027-26 / R1'));
    expect(revision.quotationNumber, 'QT-AN-0027-26');
  });

  test('revision label does not change preview pagination', () {
    final originalPages = QuotationPaginator.paginate(_quotation());
    final revisionPages = QuotationPaginator.paginate(
      _quotation(revisionNo: 1),
    );

    expect(revisionPages.length, originalPages.length);
    expect(
      revisionPages.map((page) => page.runtimeType),
      originalPages.map((page) => page.runtimeType),
    );
  });
}
