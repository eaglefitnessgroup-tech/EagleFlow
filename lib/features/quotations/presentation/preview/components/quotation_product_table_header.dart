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
          bottom: BorderSide(color: QuotationDocumentTheme.border, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        children: [
          _buildCell(
            'No.',
            QuotationLayoutSpec.columnFlex['sno']!,
            center: true,
          ),
          _buildCell(
            'Photo',
            QuotationLayoutSpec.columnFlex['photo']!,
            center: true,
          ),
          _buildCell('Product', QuotationLayoutSpec.columnFlex['product']!),
          _buildCell(
            'Qty',
            QuotationLayoutSpec.columnFlex['qty']!,
            center: true,
          ),
          _buildCell(
            'Price',
            QuotationLayoutSpec.columnFlex['unitPrice']!,
            right: true,
          ),
          _buildCell(
            'Disc.',
            QuotationLayoutSpec.columnFlex['discount']!,
            right: true,
          ),
          _buildCell(
            'Amount',
            QuotationLayoutSpec.columnFlex['amount']!,
            right: true,
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
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: center
              ? Alignment.center
              : right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(text, style: QuotationDocumentTheme.smallBold),
        ),
      ),
    );
  }
}
