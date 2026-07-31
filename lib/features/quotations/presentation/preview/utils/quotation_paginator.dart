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
        QuotationLayoutSpec.a4LogicalHeight - pageMarginTotal;

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

    // Orphan Balancing: Evaluate the last two pages
    if (productPages.length > 1) {
      final lastPage = productPages.last;
      final previousPage = productPages[productPages.length - 2];

      if (lastPage.items.length == 1 && previousPage.items.length > 1) {
        // Can we safely move the last item of previousPage to lastPage?
        // Let's recalculate the new height of lastPage if we do this.
        // To be safe, we must use the actual row height of the item we're moving.
        // Unfortunately we didn't store previousPage's row heights cleanly per page.
        // Let's just recalculate it for the candidate item.
        final candidateItem = previousPage.items.last;
        final TextPainter namePainter = TextPainter(
          text: TextSpan(
            text: candidateItem.name,
            style: QuotationDocumentTheme.bodyBold,
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: productTextWidth);
        final TextPainter codeBrandPainter = TextPainter(
          text: TextSpan(
            text:
                'Code: ${candidateItem.productCode ?? "—"} | Brand: ${candidateItem.brand.isNotEmpty ? candidateItem.brand : "—"}',
            style: QuotationDocumentTheme.small,
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: productTextWidth);
        double descHeight = 0;
        if (candidateItem.description != null &&
            candidateItem.description!.isNotEmpty) {
          final TextPainter descPainter = TextPainter(
            text: TextSpan(
              text: candidateItem.description,
              style: QuotationDocumentTheme.small,
            ),
            textDirection: TextDirection.ltr,
            maxLines: 2,
          )..layout(maxWidth: productTextWidth);
          descHeight = 6.0 + descPainter.height;
        }
        final double candidateContentH =
            namePainter.height + 4.0 + codeBrandPainter.height + descHeight;
        final double candidateRowHeight =
            math.max(QuotationLayoutSpec.productImageSize, candidateContentH) +
            12.5;

        // Is there room for it on the last page?
        // Last page only has header + 1 row currently.
        final double currentLastPageHeight =
            headerHeight + currentChunkHeights.first;
        final double projectedLastPageHeight =
            currentLastPageHeight + candidateRowHeight;

        // Also check if moving it would push the totals block off the page (if it currently fits)
        bool willPushTotals = false;
        bool totalsCurrentlyFit =
            (currentLastPageHeight + totalsHeight <= availablePageHeight);
        if (totalsCurrentlyFit &&
            projectedLastPageHeight + totalsHeight > availablePageHeight) {
          willPushTotals = true;
        }

        // We only move if it strictly fits without overflowing, and doesn't push totals unnecessarily
        if (projectedLastPageHeight <= availablePageHeight && !willPushTotals) {
          // It's safe! Apply the rebalance.
          previousPage.items.removeLast();
          lastPage.items.insert(0, candidateItem);
          currentHeight = projectedLastPageHeight;
        }
      }
    }

    // Evaluate Totals placement on the final product page
    if (currentHeight + totalsHeight <= availablePageHeight) {
      // Replace last page with one that has totals
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
      // Replace last page to mark it as last product page (but no totals)
      final lastPage = productPages.removeLast();
      productPages.add(
        QuotationProductsPageModel(
          items: lastPage.items,
          hasCover: lastPage.hasCover,
          isLastPage: true,
        ),
      );
      pages.addAll(productPages);
      pages.add(const QuotationTotalsPageModel());
    }

    pages.add(const QuotationTermsPageModel());
    pages.add(const QuotationBankDetailsPageModel());
    return pages;
  }
}
