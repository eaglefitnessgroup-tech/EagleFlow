import 'package:flutter/widgets.dart';

import '../../domain/quotation_line_item.dart';

class QuotationTableLayout {
  final Map<String, int> columnFlex;

  const QuotationTableLayout({required this.columnFlex});

  int flexFor(String column) => columnFlex[column] ?? 0;

  /// Whether this layout includes the given column.
  bool hasColumn(String column) =>
      columnFlex.containsKey(column) && columnFlex[column]! > 0;

  /// Sum of all flex values (used for proportional width calculations).
  int get totalFlex => columnFlex.values.fold(0, (sum, flex) => sum + flex);
}

class QuotationLayoutSpec {
  QuotationLayoutSpec._();

  // A4 Aspect Ratio: 210mm / 297mm
  static const double a4AspectRatio = 210 / 297;

  // Internal print margins (simulated 15mm-20mm)
  static const EdgeInsets pageMargin = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 24,
  );

  // Spacing
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  // Table styling
  static const double tableBorderWidth = 1.0;
  static const double tableRowHeight = 44; // reduced for maximum density
  static const double tableHeaderHeight = 32;
  static const double tableHorizontalPadding = 2;
  static const double tableHeaderVerticalPadding = 7;
  static const double productRowVerticalPadding = 2.5;
  static const double productRowBorderWidth = 0.5;
  static const double tableCellHorizontalPadding = 4;
  static const double productCellHorizontalPadding = 10;
  static const EdgeInsets productRowPadding = EdgeInsets.symmetric(
    vertical: productRowVerticalPadding,
    horizontal: tableHorizontalPadding,
  );
  static const double amountInWordsHeight = 26;
  static const double paginationSafetySpacing = 4;

  // Image constraints
  static const double productImageSize = 48;

  // Product detail typography
  static const double productNameFontSize = 11.5;
  static const double productDetailFontSize = 8;
  static const double productNameLineHeight = 1.25;
  static const double productDetailLineHeight = 1.2;
  static const double productNameMetadataSpacing = 2;
  static const double productDescriptionTopPadding = 2;

  // ── Column Proportional Widths ──────────────────────────────────────
  // Deployed production table: S No. | Photo | Product | Qty | Price |
  // Disc. | Amount. Keep this fixed so Preview and PDF always share the same
  // geometry, including zero-discount and missing-image rows.
  static const Map<String, int> columnFlex = {
    'sno': 8,
    'photo': 13,
    'product': 43,
    'qty': 6,
    'unitPrice': 10,
    'discount': 8,
    'amount': 12,
  };

  static const QuotationTableLayout productTableLayout = QuotationTableLayout(
    columnFlex: columnFlex,
  );

  /// The deployed production table uses the same seven columns for every
  /// quotation. The items parameter remains part of the API so pagination,
  /// Preview, and PDF continue to resolve the layout through one shared path.
  static QuotationTableLayout tableLayoutForItems(
    Iterable<QuotationLineItem> items,
  ) => productTableLayout;

  // Canonical A4 Logical Size (Standard 72dpi PDF size)
  static const double a4LogicalWidth = 595.0;
  static const double a4LogicalHeight = 842.0;

  static double get pageContentWidth => a4LogicalWidth - pageMargin.horizontal;

  static double get productPageAvailableHeight =>
      a4LogicalHeight -
      pageMargin.vertical -
      footerHeight -
      paginationSafetySpacing;

  static double get tableContentWidth =>
      pageContentWidth - (tableHorizontalPadding * 2);

  static double productColumnWidthFor(QuotationTableLayout tableLayout) =>
      tableContentWidth *
      (tableLayout.flexFor('product') / tableLayout.totalFlex);

  static double productTextWidthFor(QuotationTableLayout tableLayout) =>
      productColumnWidthFor(tableLayout) - (productCellHorizontalPadding * 2);

  static double conditionColumnWidthFor(QuotationTableLayout tableLayout) {
    if (!tableLayout.hasColumn('condition')) return 0;
    return tableContentWidth *
        (tableLayout.flexFor('condition') / tableLayout.totalFlex);
  }

  static double conditionTextWidthFor(QuotationTableLayout tableLayout) {
    if (!tableLayout.hasColumn('condition')) return 0;
    return conditionColumnWidthFor(tableLayout) -
        (tableCellHorizontalPadding * 2);
  }

  static double get productColumnWidth =>
      productColumnWidthFor(productTableLayout);

  static double get productTextWidth => productTextWidthFor(productTableLayout);

  /// Row height constants for conservative visual density.
  /// Fixed 48x48 photo + padding + border = 53.5px.
  static const double productRowMinimumHeightWithPhoto = 53.5;

  /// Sensible minimum row height when PHOTO column is hidden.
  /// Prevents rows from collapsing excessively while maintaining readable, premium breathing room.
  static const double productRowMinimumHeightWithoutPhoto = 50.0;

  /// Minimum row height depends on whether images are present in the layout.
  static double productRowMinimumHeightFor(QuotationTableLayout tableLayout) {
    return tableLayout.hasColumn('photo')
        ? productRowMinimumHeightWithPhoto
        : productRowMinimumHeightWithoutPhoto;
  }

  static double get productRowMinimumHeight =>
      productRowMinimumHeightFor(productTableLayout);

  // Cover geometry shared by Preview, PDF, and pagination measurement.
  static const double documentHeaderLogoWidth = 180;
  static const double documentHeaderLogoHeight = 42;
  static const double documentHeaderHorizontalSpacing = 16;
  static const double documentHeaderVerticalSpacing = 8;
  static const double coverCompanyFontSize = 8;
  static const double coverCompanyLineHeight = 1.5;
  static const double coverCompanyLabelWidth = 100;
  static const double coverCompanyRowBottomPadding = 0;
  static const double coverCompanyToCustomerSpacing = 20;
  static const double coverCustomerColumnSpacing = 32;
  static const double coverDocumentColumnWidth = 170;
  static const double coverCustomerHeadingHeight = 15;
  static const double coverCustomerHeadingSpacing = 4;
  static const double coverCustomerDividerHeight = 1.5;
  static const double coverCustomerDividerSpacing = 8;
  static const double coverCustomerLabelWidth = 70;
  static const double coverCustomerRowBottomPadding = 2;
  static const double coverBottomSpacing = 8;

  // Pagination reserves (Top/Bottom safe areas)
  static const double pageReserveTop = 40.0;
  static const double pageReserveBottom = 24.0;
  static const double footerHeight = 28.0;
}
