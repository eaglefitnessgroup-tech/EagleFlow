import 'dart:io';

import 'package:eagleflow/features/quotations/application/quotation_amount_in_words_formatter.dart';
import 'package:eagleflow/features/quotations/application/quotation_pdf_service.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/components/quotation_totals_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuotationAmountInWordsFormatter', () {
    test('formats 16275.00', () {
      expect(
        QuotationAmountInWordsFormatter.format(16275.00),
        'Sixteen Thousand Two Hundred Seventy-Five Dirhams Only',
      );
    });

    test('formats 1250.50', () {
      expect(
        QuotationAmountInWordsFormatter.format(1250.50),
        'One Thousand Two Hundred Fifty Dirhams and Fifty Fils Only',
      );
    });

    test('uses singular Dirham for 1.00', () {
      expect(QuotationAmountInWordsFormatter.format(1.00), 'One Dirham Only');
    });

    test('uses singular Fil for 1.01', () {
      expect(
        QuotationAmountInWordsFormatter.format(1.01),
        'One Dirham and One Fil Only',
      );
    });

    test('omits zero fils', () {
      expect(
        QuotationAmountInWordsFormatter.format(42.00),
        'Forty-Two Dirhams Only',
      );
    });

    test('includes non-zero fils', () {
      expect(
        QuotationAmountInWordsFormatter.format(42.05),
        'Forty-Two Dirhams and Five Fils Only',
      );
    });

    test('formats a realistic large quotation amount', () {
      expect(
        QuotationAmountInWordsFormatter.format(987654321098.76),
        'Nine Hundred Eighty-Seven Billion Six Hundred Fifty-Four Million '
        'Three Hundred Twenty-One Thousand Ninety-Eight Dirhams and '
        'Seventy-Six Fils Only',
      );
    });
  });

  test('Preview and PDF use the same shared formatter call', () {
    const formatterCall = 'QuotationAmountInWordsFormatter.format(grandTotal)';
    final previewSource = File(
      'lib/features/quotations/presentation/preview/components/'
      'quotation_totals_block.dart',
    ).readAsStringSync();
    final pdfSource = File(
      'lib/features/quotations/application/quotation_pdf_service.dart',
    ).readAsStringSync();

    expect(previewSource, contains(formatterCall));
    expect(pdfSource, contains(formatterCall));
  });

  testWidgets('long amount text stays within two Preview lines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(595, 842);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quotation = QuotationDefaults.createEmptyDraft().copyWith(
      lineItems: const [
        QuotationLineItem(
          id: 'large-amount',
          name: 'Large amount',
          brand: 'Eagle',
          unitPrice: 987654321098.76,
          quantity: 1,
        ),
      ],
      charges: QuotationDefaults.createEmptyDraft().charges.copyWith(
        vatPercentage: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 547,
            height: 180,
            child: QuotationTotalsBlock(quotation: quotation),
          ),
        ),
      ),
    );

    final amountText = tester.widget<Text>(
      find.text(QuotationAmountInWordsFormatter.format(987654321098.76)),
    );
    expect(amountText.maxLines, 2);
    expect(amountText.overflow, TextOverflow.clip);
    expect(tester.takeException(), isNull);
  });

  test('PDF generation supports the realistic large amount', () async {
    final draft = QuotationDefaults.createEmptyDraft();
    final quotation = draft.copyWith(
      lineItems: const [
        QuotationLineItem(
          id: 'large-amount',
          name: 'Large amount',
          brand: 'Eagle',
          unitPrice: 987654321098.76,
          quantity: 1,
        ),
      ],
      charges: draft.charges.copyWith(vatPercentage: 0),
    );

    final bytes = await QuotationPdfService().generatePdf(quotation);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
