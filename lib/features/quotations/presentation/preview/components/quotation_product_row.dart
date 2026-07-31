import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../application/quotation_calculator.dart';
import '../../../domain/quotation_line_item.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';
import '../quotation_document_formatters.dart';

class QuotationProductRow extends StatelessWidget {
  final int index;
  final QuotationLineItem item;

  const QuotationProductRow({
    super.key,
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = QuotationCalculator.calculateLineTotal(
      item.unitPrice,
      item.quantity,
      item.discount,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: QuotationDocumentTheme.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCell(
            index.toString(),
            QuotationLayoutSpec.columnFlex['sno']!,
            center: true,
          ),

          Expanded(
            flex: QuotationLayoutSpec.columnFlex['photo']!,
            child: Center(
              child: item.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        item.imagePath!,
                        width: QuotationLayoutSpec.productImageSize,
                        height: QuotationLayoutSpec.productImageSize,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                      ),
                    )
                  : _buildPlaceholder(),
            ),
          ),

          Expanded(
            flex: QuotationLayoutSpec.columnFlex['product']!,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: QuotationDocumentTheme.bodyBold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code: ${item.productCode ?? "—"} | Brand: ${item.brand.isNotEmpty ? item.brand : "—"}',
                    style: QuotationDocumentTheme.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null && item.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item.description!,
                        style: QuotationDocumentTheme.small.copyWith(
                          color: QuotationDocumentTheme.textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          _buildCell(
            item.quantity.toString(),
            QuotationLayoutSpec.columnFlex['qty']!,
            center: true,
          ),
          _buildCell(
            QuotationDocumentFormatters.formatCurrency(item.unitPrice),
            QuotationLayoutSpec.columnFlex['unitPrice']!,
            right: true,
          ),
          _buildCell(
            item.discount > 0 ? '${item.discount}%' : '—',
            QuotationLayoutSpec.columnFlex['discount']!,
            right: true,
          ),
          _buildCell(
            QuotationDocumentFormatters.formatCurrency(lineTotal),
            QuotationLayoutSpec.columnFlex['amount']!,
            right: true,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: QuotationLayoutSpec.productImageSize,
      height: QuotationLayoutSpec.productImageSize,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.image_not_supported,
        size: 16,
        color: AppColors.mutedText,
      ),
    );
  }

  Widget _buildCell(
    String text,
    int flex, {
    bool center = false,
    bool right = false,
    bool bold = false,
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
          child: Text(
            text,
            style: bold
                ? QuotationDocumentTheme.bodyBold
                : QuotationDocumentTheme.body,
          ),
        ),
      ),
    );
  }
}
