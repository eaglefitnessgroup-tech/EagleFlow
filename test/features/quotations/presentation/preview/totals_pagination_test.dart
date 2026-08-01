import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';

void main() {
  group('Totals Pagination Algorithm', () {
    late Quotation filledQuotation;

    setUp(() {
      filledQuotation = QuotationDefaults.createEmptyDraft().copyWith(
        customerInfo: const CustomerInfo(
          name: 'John Doe',
          company: 'Acme Corp',
        ),
      );
    });

    test('Short quotation: Products + Totals, then Info page', () {
      final quotation = filledQuotation.copyWith(
        lineItems: [
          const QuotationLineItem(
            id: '1',
            productId: 'p1',
            name: 'Product 1',
            brand: 'B',
            quantity: 1,
            unitPrice: 100,
          ),
        ],
      );
      final pages = QuotationPaginator.paginate(quotation);
      expect(pages.length, 2);
      expect(pages[0], isA<QuotationProductsPageModel>());
      expect((pages[0] as QuotationProductsPageModel).hasTotals, isTrue);
      expect(pages[1], isA<QuotationInfoPageModel>());
    });

    test(
      'Long quotation: Multiple product pages, final rows + Totals, then Info page',
      () {
        final List<QuotationLineItem> items = List.generate(
          15,
          (i) => QuotationLineItem(
            id: 'id_\$i',
            productId: 'p_\$i',
            name: 'Item \$i',
            brand: 'B',
            quantity: 1,
            unitPrice: 100,
          ),
        );
        final quotation = filledQuotation.copyWith(lineItems: items);
        final pages = QuotationPaginator.paginate(quotation);

        expect(pages.last, isA<QuotationInfoPageModel>());
        final productPages = pages
            .take(pages.length - 1)
            .toList()
            .cast<QuotationProductsPageModel>();
        expect(productPages.length, greaterThan(1));

        expect(productPages.last.hasTotals, isTrue);
        expect(productPages.last.items.isNotEmpty, isTrue);

        final totalsOnlyPages = productPages.where(
          (p) => p.hasTotals && p.items.isEmpty,
        );
        expect(totalsOnlyPages.isEmpty, isTrue);
      },
    );

    test('Totals requiring multiple rows to be rebalanced', () {
      final List<QuotationLineItem> items = List.generate(
        22,
        (i) => QuotationLineItem(
          id: 'id_\$i',
          productId: 'p_\$i',
          name: 'Item \$i',
          brand: 'B',
          quantity: 1,
          unitPrice: 100,
        ),
      );
      final quotation = filledQuotation.copyWith(lineItems: items);
      final pages = QuotationPaginator.paginate(quotation);

      final productPages = pages
          .take(pages.length - 1)
          .toList()
          .cast<QuotationProductsPageModel>();

      for (final p in productPages) {
        if (p.hasTotals) {
          expect(p.items.isNotEmpty, isTrue);
        }
      }
    });
  });
}
