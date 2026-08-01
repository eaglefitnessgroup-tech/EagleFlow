import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/preview/models/quotation_preview_page.dart';
import 'package:eagleflow/features/quotations/presentation/preview/utils/quotation_paginator.dart';

void main() {
  var filledQuotation = QuotationDefaults.createEmptyDraft().copyWith(
    customerInfo: const CustomerInfo(
      name: 'John Doe',
      company: 'Acme Corp',
    ),
  );
  
  final longDesc = List.generate(500, (index) => 'word').join(' '); 

  final quotation = filledQuotation.copyWith(
    lineItems: [
      const QuotationLineItem(id: '1', productId: 'p1', name: 'Normal Item', brand: 'B', quantity: 1, unitPrice: 100),
      QuotationLineItem(id: '2', productId: 'p2', name: 'Giant Item', brand: 'B', description: longDesc, quantity: 1, unitPrice: 100),
    ],
  );
  final pages = QuotationPaginator.paginate(quotation);
  print('Total pages: \');
  for (var p in pages) {
    if (p is QuotationProductsPageModel) {
      print('ProductPage: items=\, totals=\');
    } else {
      print('Other Page: \');
    }
  }
}
