import 'package:flutter/material.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';

class QuotationProductTableHeader extends StatelessWidget {
  const QuotationProductTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: QuotationDocumentTheme.navy, width: 1.5),
          bottom: BorderSide(
            color: QuotationDocumentTheme.textMuted,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        children: [
          _buildCell(
            'S No.',
            QuotationLayoutSpec.columnFlex['sno']!,
            center: true,
            scaleDown: false,
          ),
          _buildCell(
            'Photo',
            QuotationLayoutSpec.columnFlex['photo']!,
            center: true,
          ),
          _buildCell(
            'Product',
            QuotationLayoutSpec.columnFlex['product']!,
            horizontalPadding: 12,
          ),
          _buildCell(
            'Qty',
            QuotationLayoutSpec.columnFlex['qty']!,
            center: true,
          ),
          _buildCell(
            'Price',
            QuotationLayoutSpec.columnFlex['unitPrice']!,
            center: true,
          ),
          _buildCell(
            'Disc.',
            QuotationLayoutSpec.columnFlex['discount']!,
            center: true,
          ),
          _buildCell(
            'Amount',
            QuotationLayoutSpec.columnFlex['amount']!,
            center: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text,
    int flex, {
    bool center = false,
    bool right = false,
    bool scaleDown = true,
    double horizontalPadding = 4,
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
