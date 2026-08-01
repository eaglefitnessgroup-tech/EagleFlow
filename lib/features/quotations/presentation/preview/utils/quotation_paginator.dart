import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../models/quotation_preview_page.dart';
import '../quotation_layout_spec.dart';
import '../quotation_document_theme.dart';
import 'quotation_cover_section_measurer.dart';
import '../../../domain/quotation_line_item.dart';

class QuotationPaginator {
  static List<QuotationPreviewPage> paginate(Quotation quotation) {
    final List<QuotationPreviewPage> pages = [];

    // Defensive check
    if (quotation.lineItems.isEmpty) {
      pages.add(
        const QuotationProductsPageModel(
          items: [],
          hasCover: true,
          hasTotals: true,
          isLastPage: true,
        ),
      );
      return pages;
    }

    // A4 Logical Height Constraints
    final double pageMarginTotal = QuotationLayoutSpec.pageMargin.vertical;
    final double availablePageHeight =
        QuotationLayoutSpec.a4LogicalHeight -
        pageMarginTotal -
        QuotationLayoutSpec.footerHeight -
        4.0; // Safety tolerance above footer

    // Calculate Product Column width to measure text wrapping
    final double contentWidth =
        QuotationLayoutSpec.a4LogicalWidth -
        QuotationLayoutSpec.pageMargin.horizontal * 2;
    const double tablePadding = 4.0;
    final double flexSpace = contentWidth - tablePadding;
    final double productColWidth =
        flexSpace * (QuotationLayoutSpec.columnFlex['product']! / 100.0);
    final double productTextWidth = productColWidth - 24;

    const double headerHeight = 42.0;
    final double coverSectionHeight =
        QuotationCoverSectionMeasurer.measureHeight(quotation);

    int chargeRows = 2; // Subtotal + VAT
    if (quotation.charges.deliveryCharges > 0) chargeRows++;
    if (quotation.charges.installationCharges > 0) chargeRows++;
    if (quotation.charges.otherCharges > 0) chargeRows++;
    if (quotation.charges.overallDiscount > 0) chargeRows++;
    // Explicit totals height: 24 padding + rows(20) + 40 bottom block (4+1+4+31)
    final double totalsHeight = 24.0 + (chargeRows * 20.0) + 40.0;

    List<QuotationProductsPageModel> productPages = [];
    List<QuotationLineItem> currentChunk = [];
    List<double> currentChunkHeights = [];
    double currentHeight = coverSectionHeight + headerHeight;
    bool isFirstPage = true;

    for (int i = 0; i < quotation.lineItems.length; i++) {
      final item = quotation.lineItems[i];

      final TextPainter namePainter = TextPainter(
        text: TextSpan(text: item.name, style: QuotationDocumentTheme.bodyBold),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: productTextWidth);

      final TextPainter codeBrandPainter = TextPainter(
        text: TextSpan(
          text:
              'Code: ${item.productCode ?? "—"} | Brand: ${item.brand.isNotEmpty ? item.brand : "—"}',
          style: QuotationDocumentTheme.small,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: productTextWidth);

      double descHeight = 0;
      if (item.description != null && item.description!.isNotEmpty) {
        final TextPainter descPainter = TextPainter(
          text: TextSpan(
            text: item.description,
            style: QuotationDocumentTheme.small.copyWith(
              color: QuotationDocumentTheme.textMain,
              height: 1.3,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: productTextWidth);
        descHeight = 2.0 + descPainter.height;
      }

      final double contentH =
          namePainter.height + 2.0 + codeBrandPainter.height + descHeight;
      // 8px vertical padding + 0.5px border
      final double rowHeight =
          math.max(QuotationLayoutSpec.productImageSize, contentH) + 8.5;

      final double remainingHeight = availablePageHeight - currentHeight;

      bool forceNewPage = false;
      if (isFirstPage && currentChunk.length >= 5) {
        forceNewPage = true;
      }

      if (rowHeight <= remainingHeight + 0.1 && !forceNewPage) {
        currentChunk.add(item);
        currentChunkHeights.add(rowHeight);
        currentHeight += rowHeight;
      } else {
        productPages.add(
          QuotationProductsPageModel(
            items: List.from(currentChunk),
            hasCover: isFirstPage,
          ),
        );
        isFirstPage = false;
        currentChunk = [item];
        currentChunkHeights = [rowHeight];
        currentHeight = headerHeight + rowHeight;
      }
    }

    // Add the final chunk
    productPages.add(
      QuotationProductsPageModel(
        items: List.from(currentChunk),
        hasCover: isFirstPage,
      ),
    );

    final int totalProducts = quotation.lineItems.length;

    if (totalProducts <= 4) {
      // Case A: 1 to 4 products. Place totals immediately after the final product.
      final lastPage = productPages.removeLast();
      productPages.add(
        QuotationProductsPageModel(
          items: lastPage.items,
          hasCover: lastPage.hasCover,
          hasTotals: true,
          isLastPage: true,
        ),
      );
      pages.addAll(productPages);
    } else {
      // Case B: More than 4 products
      if (productPages.length == 1) {
        // All products (e.g. 5) fit on Page 1. Do not reserve totals space on Page 1.
        final lastPage = productPages.removeLast();
        productPages.add(
          QuotationProductsPageModel(
            items: lastPage.items,
            hasCover: lastPage.hasCover,
            hasTotals: false,
            isLastPage: false,
          ),
        );
        productPages.add(
          const QuotationProductsPageModel(
            items: [],
            hasCover: false,
            hasTotals: true,
            isLastPage: true,
          ),
        );
        pages.addAll(productPages);
      } else {
        // Multiple pages. Continue using the existing totals-balancing algorithm on the final product page.
        if (currentHeight + totalsHeight <= availablePageHeight) {
          final lastPage = productPages.removeLast();
          productPages.add(
            QuotationProductsPageModel(
              items: lastPage.items,
              hasCover: lastPage.hasCover,
              hasTotals: true,
              isLastPage: true,
            ),
          );
          pages.addAll(productPages);
        } else {
          final lastPage = productPages.removeLast();
          List<QuotationLineItem> newPageItems = [];
          double newPageRowsHeight = 0;
          bool resolved = false;

          while (lastPage.items.isNotEmpty) {
            final itemToMove = lastPage.items.removeLast();
            final itemHeight = currentChunkHeights.removeLast();

            newPageItems.insert(0, itemToMove);
            newPageRowsHeight += itemHeight;

            final double projectedNewPageHeight =
                headerHeight + newPageRowsHeight + totalsHeight;

            if (projectedNewPageHeight <= availablePageHeight) {
              resolved = true;
              break;
            }
          }

          if (resolved) {
            if (lastPage.items.isNotEmpty) {
              productPages.add(lastPage);
            }
            productPages.add(
              QuotationProductsPageModel(
                items: newPageItems,
                hasCover: false,
                hasTotals: true,
                isLastPage: true,
              ),
            );
            pages.addAll(productPages);
          } else {
            lastPage.items.addAll(newPageItems);
            productPages.add(
              QuotationProductsPageModel(
                items: lastPage.items,
                hasCover: lastPage.hasCover,
                hasTotals: false,
                isLastPage: true,
              ),
            );
            pages.addAll(productPages);

            pages.add(
              const QuotationProductsPageModel(
                items: [],
                hasCover: false,
                hasTotals: true,
                isLastPage: true,
              ),
            );
          }
        }
      }
    }

    pages.add(const QuotationInfoPageModel());
    return pages;
  }
}
