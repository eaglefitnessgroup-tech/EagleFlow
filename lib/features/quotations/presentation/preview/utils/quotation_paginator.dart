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
        QuotationLayoutSpec.footerHeight;

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
    // New tighter totals height: 24 padding + rows(20) + 9 divider + 40 grand total
    final double totalsHeight = 24.0 + (chargeRows * 20.0) + 49.0;

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
            style: QuotationDocumentTheme.small,
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: productTextWidth);
        descHeight = 6.0 + descPainter.height;
      }

      final double contentH =
          namePainter.height + 4.0 + codeBrandPainter.height + descHeight;
      // 12px vertical padding + 0.5px border
      final double rowHeight =
          math.max(QuotationLayoutSpec.productImageSize, contentH) + 12.5;

      if (currentHeight + rowHeight > availablePageHeight) {
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
      } else {
        currentChunk.add(item);
        currentChunkHeights.add(rowHeight);
        currentHeight += rowHeight;
      }
    }

    // Add the final chunk
    productPages.add(
      QuotationProductsPageModel(
        items: List.from(currentChunk),
        hasCover: isFirstPage,
      ),
    );

    // Evaluate Totals placement on the final product page
    if (currentHeight + totalsHeight <= availablePageHeight) {
      // It fits on the current last page
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
      // It does not fit. Try to create a new page by pulling rows from the end of the last page.
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
          // We found a balance!
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
            hasCover: false, // It's a new page
            hasTotals: true,
            isLastPage: true,
          ),
        );
        pages.addAll(productPages);
      } else {
        // Fallback: Even one row + totals didn't fit, or we exhausted the page.
        // Restore the original page.
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

        // Safe totals-only fallback
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

    pages.add(const QuotationInfoPageModel());
    return pages;
  }
}
