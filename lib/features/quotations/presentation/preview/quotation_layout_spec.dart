import 'package:flutter/widgets.dart';

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
  static const double tableHeaderHeight = 42;

  // Image constraints
  static const double productImageSize = 32; // optimized compact size

  // Column Proportional Widths
  static const Map<String, int> columnFlex = {
    'sno': 4,
    'photo': 8,
    'product': 52,
    'qty': 6,
    'unitPrice': 10,
    'discount': 8,
    'amount': 12,
  };

  // Canonical A4 Logical Size (Standard 72dpi PDF size)
  static const double a4LogicalWidth = 595.0;
  static const double a4LogicalHeight = 842.0;

  // Pagination reserves (Top/Bottom safe areas)
  static const double pageReserveTop = 40.0;
  static const double pageReserveBottom = 24.0;
  static const double footerHeight = 28.0;
}
