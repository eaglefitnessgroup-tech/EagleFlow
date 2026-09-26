import 'package:flutter/material.dart';

import '../../../../products/domain/product.dart';
import '../../../../products/presentation/widgets/product_image.dart';
import '../../../application/quotation_calculator.dart';
import '../../../domain/quotation_line_item.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';
import '../quotation_document_formatters.dart';

import 'quotation_numeric_fit_helper.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
            child: Center(child: _buildProductImage(item)),
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
                    style: QuotationDocumentTheme.bodyBold.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    QuotationDocumentFormatters.formatProductMetadata(
                      item.productCode,
                      item.brand,
                    ),
                    style: QuotationDocumentTheme.small.copyWith(
                      fontSize: QuotationLayoutSpec.productDetailFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.condition != null)
                    Text(
                      QuotationDocumentFormatters.formatProductCondition(
                        item.condition,
                      )!,
                      style: QuotationDocumentTheme.small.copyWith(
                        fontSize: QuotationLayoutSpec.productDetailFontSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.description != null && item.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        QuotationDocumentFormatters.formatSpecification(
                              item.description,
                            ) ??
                            '',
                        style: QuotationDocumentTheme.small.copyWith(
                          fontSize: QuotationLayoutSpec.productDetailFontSize,
                          color: QuotationDocumentTheme.textMain,
                          height: 1.3,
                        ),
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                ],
              ),
            ),
          ),

          QuotationNumericFitHelper.buildPreviewCell(
            item.quantity.toString(),
            QuotationLayoutSpec.columnFlex['qty']!,
            center: true,
          ),
          QuotationNumericFitHelper.buildPreviewCell(
            QuotationDocumentFormatters.formatCurrency(item.unitPrice),
            QuotationLayoutSpec.columnFlex['unitPrice']!,
            center: true,
          ),
          QuotationNumericFitHelper.buildPreviewCell(
            item.discount > 0 ? '${item.discount}%' : '—',
            QuotationLayoutSpec.columnFlex['discount']!,
            center: true,
          ),
          QuotationNumericFitHelper.buildPreviewCell(
            QuotationDocumentFormatters.formatCurrency(lineTotal),
            QuotationLayoutSpec.columnFlex['amount']!,
            center: true,
            bold: true,
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

  Widget _buildProductImage(QuotationLineItem item) {
    if (item.imageId != null || item.imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ProductImage(
          product: Product(
            id: item.productId ?? item.id,
            productCode: item.productCode ?? '',
            name: item.name,
            category: '',
            brand: item.brand,
            sellingPrice: item.unitPrice,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            imageId: item.imageId,
            imageBytes: item.imageBytes,
          ),
          width: QuotationLayoutSpec.productImageSize,
          height: QuotationLayoutSpec.productImageSize,
          fit: BoxFit.contain,
          errorIconSize: 20,
        ),
      );
    } else if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          item.imagePath!,
          width: QuotationLayoutSpec.productImageSize,
          height: QuotationLayoutSpec.productImageSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stackTrace) {
            debugPrint('Product image failed: ${item.imagePath} — $error');
            return const SizedBox.shrink();
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
