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
  final QuotationTableLayout tableLayout;

  const QuotationProductRow({
    super.key,
    required this.index,
    required this.item,
    this.tableLayout = QuotationLayoutSpec.productTableLayout,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = QuotationCalculator.calculateLineTotal(
      item.unitPrice,
      item.quantity,
      item.discount,
    );

    return Container(
      constraints: BoxConstraints(
        minHeight: QuotationLayoutSpec.productRowMinimumHeightFor(tableLayout),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: QuotationDocumentTheme.border,
            width: QuotationLayoutSpec.productRowBorderWidth,
          ),
        ),
      ),
      padding: QuotationLayoutSpec.productRowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCell(
            index.toString(),
            tableLayout.flexFor('sno'),
            center: true,
          ),

          Expanded(
            flex: tableLayout.flexFor('photo'),
            child: Center(child: _buildProductImage(item)),
          ),

          Expanded(
            flex: tableLayout.flexFor('product'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: QuotationLayoutSpec.productCellHorizontalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: QuotationDocumentTheme.bodyBold.copyWith(
                      fontSize: QuotationLayoutSpec.productNameFontSize,
                      fontWeight: FontWeight.w500,
                      height: QuotationLayoutSpec.productNameLineHeight,
                    ),
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(
                    height: QuotationLayoutSpec.productNameMetadataSpacing,
                  ),
                  Text(
                    QuotationDocumentFormatters.formatCompactProductMetadata(
                      item.productCode,
                      item.brand,
                    ),
                    style: QuotationDocumentTheme.small.copyWith(
                      fontSize: QuotationLayoutSpec.productDetailFontSize,
                      height: QuotationLayoutSpec.productDetailLineHeight,
                    ),
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                  if (item.condition != null)
                    Text(
                      QuotationDocumentFormatters.formatProductCondition(
                        item.condition,
                      )!,
                      style: QuotationDocumentTheme.small.copyWith(
                        fontSize: QuotationLayoutSpec.productDetailFontSize,
                        height: QuotationLayoutSpec.productDetailLineHeight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.description != null && item.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: QuotationLayoutSpec.productDescriptionTopPadding,
                      ),
                      child: Text(
                        QuotationDocumentFormatters.formatCompactSpecification(
                              item.description,
                            ) ??
                            '',
                        style: QuotationDocumentTheme.small.copyWith(
                          fontSize: QuotationLayoutSpec.productDetailFontSize,
                          color: QuotationDocumentTheme.textMain,
                          height: QuotationLayoutSpec.productDetailLineHeight,
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
            tableLayout.flexFor('qty'),
            center: true,
          ),
          QuotationNumericFitHelper.buildPreviewCell(
            QuotationDocumentFormatters.formatCurrency(item.unitPrice),
            tableLayout.flexFor('unitPrice'),
            center: true,
          ),
          QuotationNumericFitHelper.buildPreviewCell(
            QuotationDocumentFormatters.formatDiscount(item.discount),
            tableLayout.flexFor('discount'),
            center: true,
          ),
          QuotationNumericFitHelper.buildPreviewCell(
            QuotationDocumentFormatters.formatCurrency(lineTotal),
            tableLayout.flexFor('amount'),
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
        padding: const EdgeInsets.symmetric(
          horizontal: QuotationLayoutSpec.tableCellHorizontalPadding,
        ),
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
    return const SizedBox(
      width: QuotationLayoutSpec.productImageSize,
      height: QuotationLayoutSpec.productImageSize,
    );
  }
}
