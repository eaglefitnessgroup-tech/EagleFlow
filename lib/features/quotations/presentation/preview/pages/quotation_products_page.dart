import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../models/quotation_preview_page.dart';
import '../components/quotation_product_table_header.dart';
import '../components/quotation_product_row.dart';
import '../components/quotation_totals_block.dart';
import 'quotation_cover_section.dart';

class QuotationProductsPage extends StatelessWidget {
  final Quotation quotation;
  final QuotationProductsPageModel model;
  final int startIndex;

  const QuotationProductsPage({
    super.key,
    required this.quotation,
    required this.model,
    required this.startIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (model.hasCover) QuotationCoverSection(quotation: quotation),
        const QuotationProductTableHeader(),
        ...model.items.asMap().entries.map((entry) {
          final itemIndex = startIndex + entry.key + 1;
          return QuotationProductRow(
            key: ValueKey(entry.value.id),
            index: itemIndex,
            item: entry.value,
          );
        }),
        if (model.hasTotals) ...[
          const Spacer(),
          QuotationTotalsBlock(quotation: quotation),
        ],
      ],
    );
  }
}
