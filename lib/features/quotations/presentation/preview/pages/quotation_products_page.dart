import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../models/quotation_preview_page.dart';
import '../components/quotation_product_table_header.dart';
import '../components/quotation_product_row.dart';
import '../components/quotation_totals_block.dart';
import '../quotation_layout_spec.dart';
import 'quotation_cover_section.dart';

class QuotationProductsPage extends StatelessWidget {
  final Quotation quotation;
  final QuotationProductsPageModel model;
  final int startIndex;
  final String? salespersonName;

  const QuotationProductsPage({
    super.key,
    required this.quotation,
    required this.model,
    required this.startIndex,
    this.salespersonName,
  });

  @override
  Widget build(BuildContext context) {
    final tableLayout = QuotationLayoutSpec.tableLayoutForItems(
      quotation.lineItems,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (model.hasCover)
          QuotationCoverSection(
            quotation: quotation,
            salespersonName: salespersonName,
          ),
        if (model.items.isNotEmpty)
          QuotationProductTableHeader(tableLayout: tableLayout),
        ...model.items.asMap().entries.map((entry) {
          final itemIndex = startIndex + entry.key + 1;
          return QuotationProductRow(
            key: ValueKey(entry.value.id),
            index: itemIndex,
            item: entry.value,
            tableLayout: tableLayout,
          );
        }),
        if (model.hasTotals && model.pinTotalsToBottom) const Spacer(),
        if (model.hasTotals) QuotationTotalsBlock(quotation: quotation),
        if (model.hasTotals && model.pinTotalsToBottom)
          const SizedBox(height: QuotationLayoutSpec.paginationSafetySpacing),
      ],
    );
  }
}
