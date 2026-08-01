import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';

void main() {
  group('Quotation Paginator - Unified Flow', () {
    late Quotation baseQuotation;

    setUp(() {
      baseQuotation = QuotationDefaults.createEmptyDraft();
    });

    test('Page ordering is Cover+Products -> optional Totals', () {
      final item = const QuotationLineItem(
        id: '1',
        productId: 'p1',
        name: 'Item 1',
        brand: 'B1',
        quantity: 1,
        unitPrice: 10,
      );
      final quotation = baseQuotation.copyWith(lineItems: [item]);

      final pages = QuotationPaginator.paginate(quotation);
      expect(pages.length, 2);
      expect(pages[0] is QuotationProductsPageModel, true);

      final firstPage = pages[0] as QuotationProductsPageModel;
      expect(firstPage.hasCover, true);
      expect(firstPage.hasTotals, true);
      expect(firstPage.isLastPage, true);
    });

    test('Every line item appears exactly once across all pages', () {
      final lineItems = List.generate(
        15, // 15 items should span across multiple pages
        (i) => QuotationLineItem(
          id: 'item_$i',
          productId: 'p$i',
          name: 'Item $i',
          brand: 'B',
          quantity: 1,
          unitPrice: 10,
        ),
      );

      final quotation = baseQuotation.copyWith(lineItems: lineItems);
      final pages = QuotationPaginator.paginate(quotation);

      final productPages = pages
          .whereType<QuotationProductsPageModel>()
          .toList();

      expect(productPages.isNotEmpty, true);
      expect(productPages.first.hasCover, true);

      for (int i = 1; i < productPages.length; i++) {
        expect(productPages[i].hasCover, false);
      }

      final allItems = productPages.expand((p) => p.items).toList();
      expect(allItems.length, 15);

      final ids = allItems.map((i) => i.id).toSet();
      expect(ids.length, 15); // Unique, no duplicates
    });
  });
}
