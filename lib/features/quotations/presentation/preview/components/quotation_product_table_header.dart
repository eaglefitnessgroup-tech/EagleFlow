import 'package:flutter/material.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';

class QuotationProductTableHeader extends StatelessWidget {
  final QuotationTableLayout tableLayout;

  const QuotationProductTableHeader({
    super.key,
    this.tableLayout = QuotationLayoutSpec.productTableLayout,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: QuotationLayoutSpec.tableHeaderHeight,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: QuotationDocumentTheme.dividerBorderSide,
            bottom: QuotationDocumentTheme.dividerBorderSide,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: QuotationLayoutSpec.tableHeaderVerticalPadding,
          horizontal: QuotationLayoutSpec.tableHorizontalPadding,
        ),
        child: Row(
          children: [
            _buildCell(
              'S No.',
              tableLayout.flexFor('sno'),
              center: true,
              scaleDown: false,
            ),
            _buildCell('Photo', tableLayout.flexFor('photo'), center: true),
            _buildCell(
              'Product',
              tableLayout.flexFor('product'),
              horizontalPadding:
                  QuotationLayoutSpec.productCellHorizontalPadding,
            ),
            _buildCell('Qty', tableLayout.flexFor('qty'), center: true),
            _buildCell('Price', tableLayout.flexFor('unitPrice'), center: true),
            _buildCell('Disc.', tableLayout.flexFor('discount'), center: true),
            _buildCell('Amount', tableLayout.flexFor('amount'), center: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    String text,
    int flex, {
    bool center = false,
    bool right = false,
    bool scaleDown = true,
    double horizontalPadding = QuotationLayoutSpec.tableCellHorizontalPadding,
  }) {
    final alignment = center
        ? Alignment.center
        : right
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final label = Text(text, style: QuotationDocumentTheme.smallBold);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: scaleDown
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: label,
              )
            : Align(alignment: alignment, child: label),
      ),
    );
  }
}
