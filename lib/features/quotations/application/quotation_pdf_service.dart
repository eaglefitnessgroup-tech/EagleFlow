import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/company_profile.dart';
import '../../../../core/utils/pdf_image_loader.dart';
import '../../products/domain/product.dart';
import '../domain/quotation.dart';
import '../domain/quotation_line_item.dart';
import '../presentation/preview/models/quotation_preview_page.dart';
import '../presentation/preview/quotation_document_formatters.dart';
import '../presentation/preview/utils/quotation_paginator.dart';
import '../presentation/preview/quotation_layout_spec.dart';
import 'quotation_calculator.dart';
import 'quotation_amount_in_words_formatter.dart';
import '../../../../core/di/service_locator.dart';
import 'salesperson_name_resolver.dart';
import '../presentation/preview/components/quotation_numeric_fit_helper.dart';

class QuotationPdfRenderTrace {
  final List<String> exportedItemIds = [];
  final List<int> productPageItemCounts = [];
  final List<int> totalsPageNumbers = [];
  final List<double> productPageUsedHeights = [];
  final List<double> measuredRowHeights = [];
  int pageCount = 0;
  double measuredCoverHeight = 0;
  double measuredHeaderHeight = 0;
  double measuredTotalsHeight = 0;
  double availablePageHeight = 0;

  void reset() {
    exportedItemIds.clear();
    productPageItemCounts.clear();
    totalsPageNumbers.clear();
    productPageUsedHeights.clear();
    measuredRowHeights.clear();
    pageCount = 0;
    measuredCoverHeight = 0;
    measuredHeaderHeight = 0;
    measuredTotalsHeight = 0;
    availablePageHeight = 0;
  }
}

class QuotationPdfService {
  late pw.Font _fontRegular;
  late pw.Font _fontMedium;
  late pw.Font _fontSemiBold;
  late pw.Font _fontBold;

  final PdfColor _navy = const PdfColor.fromInt(0xFF0F172A);
  final PdfColor _textMain = const PdfColor.fromInt(0xFF334155);
  final PdfColor _textMuted = const PdfColor.fromInt(0xFF64748B);
  final PdfColor _border = const PdfColor.fromInt(0xFFF1F5F9);
  final PdfColor _dividerColor = const PdfColor.fromInt(0xFFE2E8F0);
  final PdfColor _red = const PdfColor.fromInt(0xFFF44336);
  static const double _dividerThickness = 1;

  Future<Uint8List> generatePdf(
    Quotation quotation, {
    @visibleForTesting QuotationPdfRenderTrace? renderTrace,
  }) async {
    renderTrace?.reset();
    // 1. Pre-cache all product images securely
    for (final item in quotation.lineItems) {
      await PdfImageLoader.loadProductImage(
        Product(
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
      );
    }

    // Also preload the company logo
    await PdfImageLoader.loadAsset('assets/logos/logo_head_cropped.png');

    // Resolve Salesperson Name
    final currentUser = ServiceLocator().authController.currentUser;
    String resolvedSalesmanName = SalespersonNameResolver.resolve(
      salespersonId: quotation.salespersonId,
      currentUser: currentUser,
    );
    try {
      if (currentUser == null || currentUser.id != quotation.salespersonId) {
        final users = await ServiceLocator().authRepository.getUsers();
        resolvedSalesmanName = SalespersonNameResolver.resolve(
          salespersonId: quotation.salespersonId,
          currentUser: currentUser,
          profiles: users,
        );
      }
    } catch (_) {}

    // 2. Setup Document & Fonts
    final pdf = pw.Document();
    _fontRegular = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Regular.ttf',
      ),
    );
    _fontMedium = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Medium.ttf',
      ),
    );
    _fontSemiBold = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-SemiBold.ttf',
      ),
    );
    _fontBold = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Bold.ttf',
      ),
    );

    // 3. Measure with the same PDF widgets and fonts that will be exported,
    // then paginate from those rendered dimensions.
    final tableLayout = QuotationLayoutSpec.tableLayoutForItems(
      quotation.lineItems,
    );
    final measurementDocument = pw.Document();
    final measurementPage = PdfPage(
      measurementDocument.document,
      pageFormat: PdfPageFormat.a4,
    );
    final measurementCanvas = measurementPage.getGraphics();
    final pdfContentWidth =
        PdfPageFormat.a4.width - QuotationLayoutSpec.pageMargin.horizontal;
    final availablePdfHeight =
        PdfPageFormat.a4.height -
        QuotationLayoutSpec.pageMargin.vertical -
        QuotationLayoutSpec.footerHeight -
        QuotationLayoutSpec.paginationSafetySpacing;

    double measureWidget(pw.Widget widget) {
      return pw.Widget.measure(
        widget,
        page: measurementPage,
        canvas: measurementCanvas,
        constraints: pw.BoxConstraints(
          maxWidth: pdfContentWidth,
          maxHeight: double.infinity,
        ),
      ).y;
    }

    final measuredCoverHeight = measureWidget(
      _buildCoverSection(quotation, resolvedSalesmanName),
    );
    final measuredHeaderHeight = measureWidget(_buildTableHeader(tableLayout));
    final measuredTotalsHeight = measureWidget(_buildTotalsBlock(quotation));
    final measuredRowHeights = Map<QuotationLineItem, double>.identity();
    for (int i = 0; i < quotation.lineItems.length; i++) {
      final item = quotation.lineItems[i];
      measuredRowHeights[item] = measureWidget(
        _buildProductRow(i + 1, item, tableLayout),
      );
    }

    final pages = QuotationPaginator.paginate(
      quotation,
      salespersonName: resolvedSalesmanName,
      measuredCoverSectionHeight: measuredCoverHeight,
      measuredTableHeaderHeight: measuredHeaderHeight,
      measuredTotalsHeight: measuredTotalsHeight,
      measuredAvailablePageHeight: availablePdfHeight,
      measuredRowHeight: (item, _) => measuredRowHeights[item]!,
    );

    final exportedItems = pages
        .whereType<QuotationProductsPageModel>()
        .expand((page) => page.items)
        .toList();
    final preservesEveryItem =
        exportedItems.length == quotation.lineItems.length &&
        List.generate(
          exportedItems.length,
          (index) =>
              identical(exportedItems[index], quotation.lineItems[index]),
        ).every((matches) => matches);
    if (!preservesEveryItem) {
      throw StateError(
        'Quotation PDF pagination must preserve every line item exactly once.',
      );
    }

    final productPageUsedHeights = <double>[];
    for (final page in pages.whereType<QuotationProductsPageModel>()) {
      final usedHeight =
          (page.hasCover ? measuredCoverHeight : 0) +
          (page.items.isNotEmpty ? measuredHeaderHeight : 0) +
          page.items.fold<double>(
            0,
            (height, item) => height + measuredRowHeights[item]!,
          ) +
          (page.hasTotals ? measuredTotalsHeight : 0);
      if (usedHeight > availablePdfHeight + 0.1) {
        throw StateError(
          'Quotation PDF page content exceeds the printable height '
          '(${usedHeight.toStringAsFixed(2)} > '
          '${availablePdfHeight.toStringAsFixed(2)}).',
        );
      }
      productPageUsedHeights.add(usedHeight);
    }

    for (int i = 0; i < pages.length; i++) {
      final pageModel = pages[i];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 24, // QuotationLayoutSpec.pageMargin.horizontal
            vertical: 24, // QuotationLayoutSpec.pageMargin.vertical
          ),
          build: (pw.Context context) {
            int pageStartIndex = 0;
            for (int j = 0; j < i; j++) {
              if (pages[j] is QuotationProductsPageModel) {
                pageStartIndex +=
                    (pages[j] as QuotationProductsPageModel).items.length;
              }
            }

            return pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (pageModel is QuotationProductsPageModel) ...[
                        if (pageModel.hasCover)
                          _buildCoverSection(quotation, resolvedSalesmanName),
                        if (pageModel.items.isNotEmpty)
                          _buildTableHeader(tableLayout),
                        ...pageModel.items.asMap().entries.map((entry) {
                          final itemIndex = pageStartIndex + entry.key + 1;
                          return _buildProductRow(
                            itemIndex,
                            entry.value,
                            tableLayout,
                          );
                        }),
                        if (pageModel.hasTotals) _buildTotalsBlock(quotation),
                      ] else if (pageModel is QuotationInfoPageModel) ...[
                        _buildHeader(),
                        _buildInfoPageContent(quotation),
                      ],
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    if (renderTrace != null) {
      renderTrace.pageCount = pages.length;
      renderTrace.exportedItemIds.addAll(exportedItems.map((item) => item.id));
      renderTrace.productPageItemCounts.addAll(
        pages.whereType<QuotationProductsPageModel>().map(
          (page) => page.items.length,
        ),
      );
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        if (page is QuotationProductsPageModel && page.hasTotals) {
          renderTrace.totalsPageNumbers.add(i + 1);
        }
      }
      renderTrace.productPageUsedHeights.addAll(productPageUsedHeights);
      renderTrace.measuredRowHeights.addAll(
        quotation.lineItems.map((item) => measuredRowHeights[item]!),
      );
      renderTrace.measuredCoverHeight = measuredCoverHeight;
      renderTrace.measuredHeaderHeight = measuredHeaderHeight;
      renderTrace.measuredTotalsHeight = measuredTotalsHeight;
      renderTrace.availablePageHeight = availablePdfHeight;
    }
    return bytes;
  }

  pw.Widget _buildHeader() {
    final profile = CompanyProfile.defaultProfile;

    // Try to get logo from cache
    final logoBytes = PdfImageLoader.loadAssetSync(
      'assets/logos/logo_head_cropped.png',
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (logoBytes != null)
              pw.Image(
                pw.MemoryImage(logoBytes),
                width: QuotationLayoutSpec.documentHeaderLogoWidth,
                height: QuotationLayoutSpec.documentHeaderLogoHeight,
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.centerLeft,
              )
            else
              pw.SizedBox(
                width: QuotationLayoutSpec.documentHeaderLogoWidth,
                height: QuotationLayoutSpec.documentHeaderLogoHeight,
              ),

            pw.SizedBox(
              width: QuotationLayoutSpec.documentHeaderHorizontalSpacing,
            ),
            pw.Text(
              profile.website,
              style: pw.TextStyle(
                font: _fontMedium,
                fontSize: 10,
                color: _textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: QuotationLayoutSpec.documentHeaderVerticalSpacing),
        _buildDocumentDivider(),
        pw.SizedBox(height: QuotationLayoutSpec.documentHeaderVerticalSpacing),
      ],
    );
  }

  pw.Divider _buildDocumentDivider() {
    return pw.Divider(
      color: _dividerColor,
      thickness: _dividerThickness,
      height: _dividerThickness,
    );
  }

  pw.BorderSide _documentDividerBorderSide() {
    return pw.BorderSide(color: _dividerColor, width: _dividerThickness);
  }

  pw.Widget _buildFixedWidthDocumentDivider(double width) {
    return pw.Container(
      width: width,
      height: 1.5,
      alignment: pw.Alignment.center,
      child: pw.Container(
        width: width,
        height: _dividerThickness,
        color: _dividerColor,
      ),
    );
  }

  @visibleForTesting
  PdfColor get documentDividerColorForTesting => _dividerColor;

  @visibleForTesting
  double get documentDividerThicknessForTesting => _dividerThickness;

  @visibleForTesting
  pw.Divider buildDocumentDividerForTesting() => _buildDocumentDivider();

  @visibleForTesting
  pw.BorderSide documentDividerBorderSideForTesting() =>
      _documentDividerBorderSide();

  @visibleForTesting
  pw.Widget buildFixedWidthDocumentDividerForTesting(double width) =>
      _buildFixedWidthDocumentDivider(width);

  @visibleForTesting
  pw.Widget buildCoverSectionForTesting(
    Quotation quotation, {
    String salespersonName = '',
  }) => _buildCoverSection(quotation, salespersonName);

  pw.Widget _buildCoverSection(Quotation quotation, String salesmanName) {
    final profile = CompanyProfile.defaultProfile;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildCompanyRow('LICENSE NO', profile.licenseNumber),
                  _buildCompanyRow('LICENSE NAME', profile.legalName),
                  _buildCompanyRow(
                    'ADDRESS',
                    '${profile.addressLine1}\n${profile.addressLine2}',
                    maxLines: 2,
                  ),
                  _buildCompanyRow('MOBILE', profile.mobile),
                  _buildCompanyRow('TELEPHONE', profile.telephone),
                  _buildCompanyRow('TRN', profile.trn),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: QuotationLayoutSpec.coverCompanyToCustomerSpacing),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingHeight,
                    child: pw.Text('QUOTATION TO', style: _smallBoldStyle()),
                  ),
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingSpacing,
                  ),
                  _buildFixedWidthDocumentDivider(130),
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerDividerSpacing,
                  ),
                  _buildCustomerRow(
                    'CUSTOMER',
                    quotation.customerInfo.name.isNotEmpty
                        ? quotation.customerInfo.name
                        : '—',
                  ),
                  _buildCustomerRow(
                    'LOCATION',
                    quotation.customerInfo.projectLocation.isNotEmpty
                        ? quotation.customerInfo.projectLocation
                        : '—',
                  ),
                  _buildCustomerRow(
                    'CONTACT',
                    quotation.customerInfo.phone.isNotEmpty
                        ? quotation.customerInfo.phone
                        : '—',
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: QuotationLayoutSpec.coverCustomerColumnSpacing),
            pw.SizedBox(
              width: QuotationLayoutSpec.coverDocumentColumnWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingHeight,
                  ),
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingSpacing,
                  ),
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerDividerHeight,
                  ),
                  pw.SizedBox(
                    height: QuotationLayoutSpec.coverCustomerDividerSpacing,
                  ),
                  _buildCustomerRow(
                    'DATE',
                    QuotationDocumentFormatters.formatDate(
                      quotation.createdDate,
                    ),
                  ),
                  _buildCustomerRow(
                    'QT NO',
                    quotation.displayQuotationNumber.isNotEmpty
                        ? quotation.displayQuotationNumber
                        : '—',
                  ),
                  _buildCustomerRow(
                    'EXPIRED',
                    QuotationDocumentFormatters.formatDate(
                      quotation.validUntil,
                    ),
                  ),
                  _buildCustomerRow(
                    'SALESMAN',
                    salesmanName.isNotEmpty ? salesmanName : '—',
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: QuotationLayoutSpec.coverBottomSpacing),
      ],
    );
  }

  pw.Widget _buildCompanyRow(String label, String value, {int maxLines = 1}) {
    return pw.SizedBox(
      height:
          QuotationLayoutSpec.coverCompanyFontSize *
          QuotationLayoutSpec.coverCompanyLineHeight *
          maxLines,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: QuotationLayoutSpec.coverCompanyLabelWidth,
            child: pw.Text(
              label,
              style: _smallStyle(
                fontSize: QuotationLayoutSpec.coverCompanyFontSize,
              ),
            ),
          ),
          pw.Text(
            ' : ',
            style: _smallStyle(
              fontSize: QuotationLayoutSpec.coverCompanyFontSize,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: _smallStyle(
                fontSize: QuotationLayoutSpec.coverCompanyFontSize,
              ),
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerRow(String label, String value) {
    return pw.ConstrainedBox(
      constraints: const pw.BoxConstraints(minHeight: 17),
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(
          bottom: QuotationLayoutSpec.coverCustomerRowBottomPadding,
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: QuotationLayoutSpec.coverCustomerLabelWidth,
              child: pw.Text(label, style: _smallStyle()),
            ),
            pw.Text(' : ', style: _smallStyle()),
            pw.Expanded(
              child: pw.Text(value, style: _smallBoldStyle(), maxLines: 2),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTableHeader(QuotationTableLayout tableLayout) {
    return pw.SizedBox(
      height: QuotationLayoutSpec.tableHeaderHeight,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: _documentDividerBorderSide(),
            bottom: _documentDividerBorderSide(),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(
          vertical: QuotationLayoutSpec.tableHeaderVerticalPadding,
          horizontal: QuotationLayoutSpec.tableHorizontalPadding,
        ),
        child: _buildTableHeaderRow(tableLayout),
      ),
    );
  }

  pw.Row _buildTableHeaderRow(QuotationTableLayout tableLayout) {
    return pw.Row(
      children: [
        _buildTableCell(
          'S No.',
          tableLayout.flexFor('sno'),
          center: true,
          scaleDown: false,
        ),
        _buildTableCell('Photo', tableLayout.flexFor('photo'), center: true),
        _buildTableCell(
          'Product',
          tableLayout.flexFor('product'),
          horizontalPadding: QuotationLayoutSpec.productCellHorizontalPadding,
        ),
        _buildTableCell('Qty', tableLayout.flexFor('qty'), center: true),
        _buildTableCell(
          'Price',
          tableLayout.flexFor('unitPrice'),
          center: true,
        ),
        _buildTableCell('Disc.', tableLayout.flexFor('discount'), center: true),
        _buildTableCell('Amount', tableLayout.flexFor('amount'), center: true),
      ],
    );
  }

  @visibleForTesting
  pw.Widget buildTableHeaderForTesting({
    QuotationTableLayout tableLayout = QuotationLayoutSpec.productTableLayout,
  }) {
    return _buildTableHeader(tableLayout);
  }

  pw.Widget _buildTableCell(
    String text,
    int flex, {
    bool center = false,
    bool right = false,
    bool scaleDown = true,
    double horizontalPadding = QuotationLayoutSpec.tableCellHorizontalPadding,
  }) {
    final alignment = center
        ? pw.Alignment.center
        : (right ? pw.Alignment.centerRight : pw.Alignment.centerLeft);
    final label = pw.Text(text, style: _smallBoldStyle(), maxLines: 1);

    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: pw.Align(
          alignment: alignment,
          child: scaleDown
              ? pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: alignment,
                  child: label,
                )
              : label,
        ),
      ),
    );
  }

  pw.Widget _buildProductRow(
    int index,
    QuotationLineItem item,
    QuotationTableLayout tableLayout,
  ) {
    final lineTotal = QuotationCalculator.calculateLineTotal(
      item.unitPrice,
      item.quantity,
      item.discount,
    );
    final imageBytes = PdfImageLoader.loadProductImageSync(
      Product(
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
    );

    return pw.Container(
      constraints: pw.BoxConstraints(
        minHeight: QuotationLayoutSpec.productRowMinimumHeightFor(tableLayout),
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: _border,
            width: QuotationLayoutSpec.productRowBorderWidth,
          ),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(
        vertical: QuotationLayoutSpec.productRowVerticalPadding,
        horizontal: QuotationLayoutSpec.tableHorizontalPadding,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildCell(
            index.toString(),
            tableLayout.flexFor('sno'),
            center: true,
          ),

          pw.Expanded(
            flex: tableLayout.flexFor('photo'),
            child: pw.Center(
              child: imageBytes != null
                  ? pw.ClipRRect(
                      horizontalRadius: 4,
                      verticalRadius: 4,
                      child: pw.Image(
                        pw.MemoryImage(imageBytes),
                        width: QuotationLayoutSpec.productImageSize,
                        height: QuotationLayoutSpec.productImageSize,
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  : pw.SizedBox(
                      width: QuotationLayoutSpec.productImageSize,
                      height: QuotationLayoutSpec.productImageSize,
                    ),
            ),
          ),

          pw.Expanded(
            flex: tableLayout.flexFor('product'),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: QuotationLayoutSpec.productCellHorizontalPadding,
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.name,
                    style: _bodyStyle(bold: true).copyWith(
                      fontSize: QuotationLayoutSpec.productNameFontSize,
                      height: QuotationLayoutSpec.productNameLineHeight,
                    ),
                  ),
                  pw.SizedBox(
                    height: QuotationLayoutSpec.productNameMetadataSpacing,
                  ),
                  pw.Text(
                    QuotationDocumentFormatters.formatCompactProductMetadata(
                      item.productCode,
                      item.brand,
                    ),
                    style: _smallStyle(
                      fontSize: QuotationLayoutSpec.productDetailFontSize,
                      height: QuotationLayoutSpec.productDetailLineHeight,
                    ),
                  ),
                  if (item.condition != null)
                    pw.Text(
                      QuotationDocumentFormatters.formatProductCondition(
                        item.condition,
                      )!,
                      style: _smallStyle(
                        fontSize: QuotationLayoutSpec.productDetailFontSize,
                        height: QuotationLayoutSpec.productDetailLineHeight,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  if (item.description != null && item.description!.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        top: QuotationLayoutSpec.productDescriptionTopPadding,
                      ),
                      child: pw.Text(
                        QuotationDocumentFormatters.formatCompactSpecification(
                              item.description,
                            ) ??
                            '',
                        style: _smallStyle(
                          fontSize: QuotationLayoutSpec.productDetailFontSize,
                          color: _textMain,
                          height: QuotationLayoutSpec.productDetailLineHeight,
                        ),
                        softWrap: true,
                        maxLines: null,
                        overflow: pw.TextOverflow.visible,
                      ),
                    ),
                ],
              ),
            ),
          ),

          QuotationNumericFitHelper.buildPdfCell(
            item.quantity.toString(),
            tableLayout.flexFor('qty'),
            _fontRegular,
            _fontSemiBold,
            center: true,
          ),
          QuotationNumericFitHelper.buildPdfCell(
            QuotationDocumentFormatters.formatCurrency(item.unitPrice),
            tableLayout.flexFor('unitPrice'),
            _fontRegular,
            _fontSemiBold,
            center: true,
          ),
          QuotationNumericFitHelper.buildPdfCell(
            QuotationDocumentFormatters.formatDiscount(item.discount),
            tableLayout.flexFor('discount'),
            _fontRegular,
            _fontSemiBold,
            center: true,
          ),
          QuotationNumericFitHelper.buildPdfCell(
            QuotationDocumentFormatters.formatCurrency(lineTotal),
            tableLayout.flexFor('amount'),
            _fontRegular,
            _fontSemiBold,
            center: true,
            bold: true,
          ),
        ],
      ),
    );
  }

  @visibleForTesting
  pw.Widget buildProductRowForTesting(
    int index,
    QuotationLineItem item, {
    QuotationTableLayout tableLayout = QuotationLayoutSpec.productTableLayout,
  }) {
    return _buildProductRow(index, item, tableLayout);
  }

  pw.Widget _buildCell(
    String text,
    int flex, {
    bool center = false,
    bool right = false,
    bool bold = false,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
          horizontal: QuotationLayoutSpec.tableCellHorizontalPadding,
        ),
        child: pw.Align(
          alignment: center
              ? pw.Alignment.center
              : (right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: bold ? _fontSemiBold : _fontRegular,
              fontSize: 12,
              color: bold ? _navy : _textMain,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildTotalsBlock(Quotation quotation) {
    final subtotal = QuotationCalculator.calculateSubtotal(quotation.lineItems);
    final vat = QuotationCalculator.calculateVAT(
      quotation.lineItems,
      quotation.charges,
    );
    final grandTotal = QuotationCalculator.calculateGrandTotal(
      quotation.lineItems,
      quotation.charges,
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4, left: 16, right: 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildTotalRow('Subtotal', subtotal),
          if (quotation.charges.deliveryCharges > 0)
            _buildTotalRow(
              'Delivery Charges',
              quotation.charges.deliveryCharges,
            ),
          if (quotation.charges.installationCharges > 0)
            _buildTotalRow(
              'Installation Charges',
              quotation.charges.installationCharges,
            ),
          if (quotation.charges.otherCharges > 0)
            _buildTotalRow('Other Charges', quotation.charges.otherCharges),
          if (quotation.charges.overallDiscount > 0)
            _buildTotalRow(
              'Overall Discount',
              -quotation.charges.overallDiscount,
              isDiscount: true,
            ),
          _buildTotalRow('VAT (${quotation.charges.vatPercentage}%)', vat),

          pw.SizedBox(height: 2),
          pw.Divider(color: _border, thickness: 1, height: 1),
          pw.SizedBox(height: 4),

          pw.SizedBox(
            height: 31,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Grand Total',
                  style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 14,
                    color: _navy,
                    letterSpacing: 0.5,
                    height: 1.4,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Container(
                  width: 140,
                  alignment: pw.Alignment.centerRight,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      QuotationDocumentFormatters.formatCurrency(grandTotal),
                      style: pw.TextStyle(
                        font: _fontBold,
                        fontSize: 16,
                        color: _navy,
                        height: 1.3,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            height: QuotationLayoutSpec.amountInWordsHeight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AMOUNT IN WORDS',
                  style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 7.5,
                    color: _textMuted,
                    letterSpacing: 0.4,
                    height: 1.1,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  QuotationAmountInWordsFormatter.format(grandTotal),
                  style: pw.TextStyle(
                    font: _fontMedium,
                    fontSize: 8,
                    color: _textMain,
                    height: 1.05,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isDiscount = false,
  }) {
    return pw.SizedBox(
      height: 20,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(label, style: _bodyStyle()),
          pw.SizedBox(width: 16),
          pw.Container(
            width: 140,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              isDiscount
                  ? '- ${QuotationDocumentFormatters.formatCurrency(amount.abs())}'
                  : QuotationDocumentFormatters.formatCurrency(amount),
              style: pw.TextStyle(
                font: isDiscount ? _fontRegular : _fontSemiBold,
                fontSize: 12,
                color: isDiscount ? _red : _navy,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoPageContent(Quotation quotation) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BANK ACCOUNT DETAILS',
          style: _smallBoldStyle(fontSize: 10.5).copyWith(letterSpacing: 0.6),
        ),
        pw.SizedBox(height: 2),
        _buildFixedWidthDocumentDivider(55),
        pw.SizedBox(height: 8),

        pw.Table(
          border: pw.TableBorder(
            verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            _buildBankTableRow(
              'BANK NAME',
              'MASHREQ BANK',
              'FAB [FIRST ABU DHABI BANK]',
            ),
            _buildBankTableRow(
              'ACCOUNT NAME',
              CompanyProfile.defaultProfile.legalName,
              'MAX EAGLE FITNESS SPORT EQUIPMENT TRADING L L C',
            ),
            _buildBankTableRow(
              'ACCOUNT NUMBER',
              '019100814712',
              '1001326712876001',
            ),
            _buildBankTableRow(
              'IBAN NUMBER',
              'AE270330000019100814712',
              'AE590351001326712876001',
            ),
            _buildBankTableRow('SWIFT CODE', 'BOMLAEAD', 'NBADAEAA'),
            _buildBankTableRow('CURRENCY', 'AED', 'AED'),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Text(
          'Terms & Conditions',
          style: pw.TextStyle(
            font: _fontBold,
            fontSize: 22,
            color: _navy,
            height: 1.3,
          ),
        ),
        pw.SizedBox(height: 12),

        _buildTermsSection(
          'Payment Terms',
          '• 50% advance payment required to confirm the order.\n• 50% balance payment required prior to delivery/installation.',
        ),
        _buildTermsSection(
          'Accepted Payment Methods',
          '• Bank Transfer (Details provided above).\n• Cheque (Subject to clearance before delivery).',
        ),
        _buildTermsSection(
          'Additional Payment Options',
          '• Credit Card payments are subject to a 2.5% surcharge.\n• Post-dated cheques are not accepted unless pre-approved in writing.',
        ),
        _buildTermsSection(
          'Delivery and Installation',
          '• Standard delivery timeline is 7-14 working days from receipt of advance payment.\n• Site must be ready and cleared for installation prior to our team\'s arrival.\n• Additional charges apply for hoisting or delivery above ground floor without service elevator access.',
        ),
        _buildTermsSection(
          'Product Warranty / Services',
          '• All equipment carries a standard 1-year warranty against manufacturing defects.\n• Warranty does not cover normal wear and tear, misuse, or damage caused by improper maintenance.\n• First preventative maintenance visit is complimentary within the first 6 months.',
        ),
        _buildTermsSection(
          'Returns and Refunds',
          '• Custom orders and special import items cannot be cancelled or refunded.\n• Standard items may be returned within 7 days in original, unopened packaging, subject to a 20% restocking charge.',
        ),
        _buildTermsSection(
          'Acknowledgement & Acceptance',
          '• By issuing a Purchase Order against this quotation, the buyer agrees to all stated terms and conditions.\n• Quotation is valid for 15 days from the date of issue.',
        ),

        if (quotation.customerNotes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text(
            'Customer Notes',
            style: pw.TextStyle(
              font: _fontBold,
              fontSize: 22,
              color: _navy,
              height: 1.3,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            quotation.customerNotes.trim(),
            style: _smallStyle(fontSize: 9.6, height: 1.3),
          ),
        ],
      ],
    );
  }

  pw.TableRow _buildBankTableRow(
    String label,
    String leftValue,
    String rightValue,
  ) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(right: 16.0, bottom: 6.0),
          child: _buildSingleBankCell(label, leftValue),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16.0, bottom: 6.0),
          child: _buildSingleBankCell(label, rightValue),
        ),
      ],
    );
  }

  pw.Widget _buildSingleBankCell(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 95,
          child: pw.Text(
            label,
            style: _smallStyle(
              fontSize: 9,
              color: PdfColors.grey700,
              height: 1.2,
            ),
          ),
        ),
        pw.Text(':  ', style: _smallBoldStyle(fontSize: 9, height: 1.2)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: _smallBoldStyle(
              fontSize: 9,
              color: PdfColors.black,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTermsSection(String title, String content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9.0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _smallBoldStyle()),
          pw.SizedBox(height: 2),
          pw.Text(
            content,
            style: _smallStyle(fontSize: 10.1, color: _textMain, height: 1.30),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.SizedBox(
      height: QuotationLayoutSpec.footerHeight,
      width: double.infinity,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Divider(color: _border, thickness: 1, height: 1),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Showroom No. SH03, Industrial Area 18, Maleha Road, Sharjah, U.A.E.  ',
                    style: _smallStyle(fontSize: 8, color: PdfColors.grey600),
                    maxLines: 1,
                  ),
                  pw.SvgImage(
                    svg:
                        '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M6.54 5c.06.89.21 1.76.45 2.59l-1.2 1.2c-.41-1.2-.67-2.47-.76-3.79h1.51m9.86 12.02c.85.24 1.72.39 2.6.45v1.49c-1.32-.09-2.59-.35-3.8-.75l1.2-1.19M7.5 3H4c-.55 0-1 .45-1 1 0 9.39 7.61 17 17 17 .55 0 1-.45 1-1v-3.49c0-.55-.45-1-1-1-1.24 0-2.45-.2-3.57-.57-.1-.04-.21-.05-.31-.05-.26 0-.51.1-.71.29l-2.2 2.2c-2.83-1.45-5.15-3.76-6.59-6.59l2.2-2.2c.28-.28.36-.67.25-1.02C8.7 6.45 8.5 5.25 8.5 4c0-.55-.45-1-1-1z" fill="#757575"/></svg>',
                    width: 10,
                    height: 10,
                  ),
                  pw.SizedBox(width: 3),
                  pw.Text(
                    '+971 653 2233 6',
                    style: _smallStyle(fontSize: 8, color: PdfColors.grey600),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TextStyle _smallStyle({
    double fontSize = 10,
    PdfColor? color,
    double height = 1.5,
  }) {
    return pw.TextStyle(
      font: _fontMedium,
      fontSize: fontSize,
      color: color ?? _textMuted,
      height: height,
    );
  }

  pw.TextStyle _smallBoldStyle({
    double fontSize = 10,
    PdfColor? color,
    double height = 1.5,
  }) {
    return pw.TextStyle(
      font: _fontBold,
      fontSize: fontSize,
      color: color ?? _navy,
      height: height,
    );
  }

  pw.TextStyle _bodyStyle({bool bold = false}) {
    return pw.TextStyle(
      font: bold ? _fontSemiBold : _fontRegular,
      fontSize: 12,
      color: bold ? _navy : _textMain,
      height: 1.6,
    );
  }
}
