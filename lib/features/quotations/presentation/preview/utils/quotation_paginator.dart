import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../models/quotation_preview_page.dart';
import '../quotation_layout_spec.dart';
import '../quotation_document_theme.dart';
import '../quotation_document_formatters.dart';
import 'quotation_cover_section_measurer.dart';
import '../../../domain/quotation_line_item.dart';

class QuotationPaginator {
  static List<QuotationPreviewPage> paginate(
    Quotation quotation, {
    String? salespersonName,
    double? measuredCoverSectionHeight,
    double? measuredTableHeaderHeight,
    double? measuredTotalsHeight,
    double? measuredAvailablePageHeight,
    double Function(QuotationLineItem item, QuotationTableLayout tableLayout)?
    measuredRowHeight,
  }) {
    final List<QuotationPreviewPage> pages = [];

    // Defensive check
    if (quotation.lineItems.isEmpty) {
      pages.add(
        const QuotationProductsPageModel(
          items: [],
          hasCover: true,
          hasTotals: true,
          pinTotalsToBottom: true,
          isLastPage: true,
        ),
      );
      return pages;
    }

    // A4 Logical Height Constraints
    final double availablePageHeight =
        measuredAvailablePageHeight ??
        QuotationLayoutSpec.productPageAvailableHeight;

    final tableLayout = QuotationLayoutSpec.tableLayoutForItems(
      quotation.lineItems,
    );
    final productTextWidth = QuotationLayoutSpec.productTextWidthFor(
      tableLayout,
    );
    final headerHeight =
        measuredTableHeaderHeight ?? QuotationLayoutSpec.tableHeaderHeight;
    final coverSectionHeight =
        measuredCoverSectionHeight ??
        QuotationCoverSectionMeasurer.measureHeight(
          quotation,
          salespersonName: salespersonName,
        );

    final double totalsHeight =
        measuredTotalsHeight ?? estimateTotalsHeight(quotation);

    List<QuotationProductsPageModel> productPages = [];
    List<QuotationLineItem> currentChunk = [];
    List<double> currentChunkHeights = [];
    double currentHeight = coverSectionHeight + headerHeight;
    bool isFirstPage = true;

    for (int i = 0; i < quotation.lineItems.length; i++) {
      final item = quotation.lineItems[i];

      final rowHeight =
          measuredRowHeight?.call(item, tableLayout) ??
          estimateProductRowHeight(
            item,
            productTextWidth: productTextWidth,
            tableLayout: tableLayout,
          );

      final double remainingHeight = availablePageHeight - currentHeight;

      if (rowHeight <= remainingHeight + 0.1) {
        currentChunk.add(item);
        currentChunkHeights.add(rowHeight);
        currentHeight += rowHeight;
      } else {
        productPages.add(
          QuotationProductsPageModel(
            items: List.from(currentChunk),
            hasCover: isFirstPage,
            hasTotals: false,
            isLastPage: false,
          ),
        );
        isFirstPage = false;
        currentChunk = [item];
        currentChunkHeights = [rowHeight];
        currentHeight = headerHeight + rowHeight;
      }
    }

    // Attach totals block to the last product page if it fits; otherwise move totals block to the next page
    if (currentHeight + totalsHeight <= availablePageHeight) {
      productPages.add(
        QuotationProductsPageModel(
          items: List.from(currentChunk),
          hasCover: isFirstPage,
          hasTotals: true,
          pinTotalsToBottom: isFirstPage,
          isLastPage: true,
        ),
      );
    } else {
      final lastRowCanShareTotals =
          currentChunk.isNotEmpty &&
          headerHeight + currentChunkHeights.last + totalsHeight <=
              availablePageHeight + 0.1;

      if (lastRowCanShareTotals) {
        final lastItem = currentChunk.removeLast();
        currentChunkHeights.removeLast();

        if (currentChunk.isNotEmpty || isFirstPage) {
          productPages.add(
            QuotationProductsPageModel(
              items: List.from(currentChunk),
              hasCover: isFirstPage,
              hasTotals: false,
              isLastPage: false,
            ),
          );
        }
        productPages.add(
          QuotationProductsPageModel(
            items: [lastItem],
            hasCover: false,
            hasTotals: true,
            isLastPage: true,
          ),
        );
      } else {
        productPages.add(
          QuotationProductsPageModel(
            items: List.from(currentChunk),
            hasCover: isFirstPage,
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
      }
    }

    pages.addAll(productPages);

    pages.add(const QuotationInfoPageModel());
    return pages;
  }

  static double estimateTotalsHeight(Quotation quotation) {
    int chargeRows = 2; // Subtotal + VAT
    if (quotation.charges.deliveryCharges > 0) chargeRows++;
    if (quotation.charges.installationCharges > 0) chargeRows++;
    if (quotation.charges.otherCharges > 0) chargeRows++;
    if (quotation.charges.overallDiscount > 0) chargeRows++;

    // Padding + charge rows + Grand Total + Amount in Words.
    return 16.0 +
        (chargeRows * 20.0) +
        40.0 +
        2.0 +
        QuotationLayoutSpec.amountInWordsHeight;
  }

  static double estimateProductRowHeight(
    QuotationLineItem item, {
    double? productTextWidth,
    QuotationTableLayout? tableLayout,
  }) {
    final layout = tableLayout ?? QuotationLayoutSpec.productTableLayout;
    final measuredTextWidth =
        productTextWidth ?? QuotationLayoutSpec.productTextWidthFor(layout);

    final namePainter = TextPainter(
      text: TextSpan(
        text: item.name,
        style: QuotationDocumentTheme.bodyBold.copyWith(
          fontSize: QuotationLayoutSpec.productNameFontSize,
          fontWeight: FontWeight.w500,
          height: QuotationLayoutSpec.productNameLineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: measuredTextWidth);

    final codeBrandPainter = TextPainter(
      text: TextSpan(
        text: QuotationDocumentFormatters.formatCompactProductMetadata(
          item.productCode,
          item.brand,
        ),
        style: QuotationDocumentTheme.small.copyWith(
          fontSize: QuotationLayoutSpec.productDetailFontSize,
          height: QuotationLayoutSpec.productDetailLineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: measuredTextWidth);

    double conditionHeight = 0;
    if (item.condition != null) {
      final conditionPainter = TextPainter(
        text: TextSpan(
          text: QuotationDocumentFormatters.formatProductCondition(
            item.condition,
          )!,
          style: QuotationDocumentTheme.small.copyWith(
            fontSize: QuotationLayoutSpec.productDetailFontSize,
            height: QuotationLayoutSpec.productDetailLineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: measuredTextWidth);
      conditionHeight = conditionPainter.height;
    }

    double descriptionHeight = 0;
    if (item.description != null && item.description!.isNotEmpty) {
      final descriptionPainter = TextPainter(
        text: TextSpan(
          text:
              QuotationDocumentFormatters.formatCompactSpecification(
                item.description,
              ) ??
              '',
          style: QuotationDocumentTheme.small.copyWith(
            fontSize: QuotationLayoutSpec.productDetailFontSize,
            color: QuotationDocumentTheme.textMain,
            height: QuotationLayoutSpec.productDetailLineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: measuredTextWidth);
      descriptionHeight =
          QuotationLayoutSpec.productDescriptionTopPadding +
          descriptionPainter.height;
    }

    final contentHeight =
        namePainter.height +
        QuotationLayoutSpec.productNameMetadataSpacing +
        codeBrandPainter.height +
        conditionHeight +
        descriptionHeight;

    final contentTotalHeight =
        contentHeight +
        (QuotationLayoutSpec.productRowVerticalPadding * 2) +
        QuotationLayoutSpec.productRowBorderWidth;

    final minRowHeight = QuotationLayoutSpec.productRowMinimumHeightFor(layout);

    return math.max(minRowHeight, contentTotalHeight);
  }
}
