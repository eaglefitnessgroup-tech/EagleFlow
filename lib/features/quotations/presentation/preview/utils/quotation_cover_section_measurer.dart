import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';
import '../../../../../core/models/company_profile.dart';

class QuotationCoverSectionMeasurer {
  /// Measures the exact logical height of the Cover Section using TextPainter.
  static double measureHeight(Quotation quotation) {
    final profile = CompanyProfile.defaultProfile;
    final double contentWidth =
        QuotationLayoutSpec.a4LogicalWidth -
        QuotationLayoutSpec.pageMargin.horizontal;

    double totalHeight = 0;

    // 1. HEADER (QuotationDocumentHeader)
    // Logo image is exactly 42px height.
    // Row crossAxisAlignment is end.
    totalHeight += 42.0; // Logo / title row
    totalHeight += 8.0; // SizedBox
    totalHeight += 1.0; // Divider
    totalHeight += 8.0; // SizedBox

    // 2. COMPANY DETAILS
    // Full width column of 6 rows
    final double companyLabelWidth = 100.0;
    final double companySeparatorWidth = _measureText(
      ' : ',
      QuotationDocumentTheme.small,
      100,
    );
    final double companyValueWidth =
        contentWidth - companyLabelWidth - companySeparatorWidth;

    totalHeight += _measureCompanyRow(profile.licenseNumber, companyValueWidth);
    totalHeight += _measureCompanyRow(profile.legalName, companyValueWidth);
    totalHeight += _measureCompanyRow(
      '${profile.addressLine1}\n${profile.addressLine2}',
      companyValueWidth,
      maxLines: 2,
    );
    totalHeight += _measureCompanyRow(profile.mobile, companyValueWidth);
    totalHeight += _measureCompanyRow(profile.telephone, companyValueWidth);
    totalHeight += _measureCompanyRow(profile.trn, companyValueWidth);

    totalHeight += 32.0; // SizedBox

    // 3. CUSTOMER & DOCUMENT INFO
    // Two columns taking Expanded (half width each), with a 32px gap.
    final double columnWidth = (contentWidth - 32.0) / 2.0;

    // Calculate Left Column (Customer)
    double leftHeight = 0;
    leftHeight += _measureText(
      'QUOTATION TO',
      QuotationDocumentTheme.smallBold,
      columnWidth,
    );
    leftHeight += 4.0; // SizedBox
    leftHeight += 1.5; // Container height
    leftHeight += 8.0; // SizedBox

    final double customerLabelWidth = 70.0;
    final double customerSeparatorWidth = companySeparatorWidth;
    final double customerValueWidth =
        columnWidth - customerLabelWidth - customerSeparatorWidth;

    leftHeight += _measureCustomerRow(
      quotation.customerInfo.name.isNotEmpty
          ? quotation.customerInfo.name
          : '—',
      customerValueWidth,
    );
    leftHeight += _measureCustomerRow(
      quotation.customerInfo.projectLocation.isNotEmpty
          ? quotation.customerInfo.projectLocation
          : '—',
      customerValueWidth,
    );
    leftHeight += _measureCustomerRow(
      quotation.customerInfo.phone.isNotEmpty
          ? quotation.customerInfo.phone
          : '—',
      customerValueWidth,
    );

    // Calculate Right Column (Document)
    double rightHeight = 0;

    // Invisible spacer to match left column's title & line
    rightHeight += _measureText(
      '',
      QuotationDocumentTheme.smallBold,
      columnWidth,
    );
    rightHeight += 4.0; // SizedBox
    rightHeight += 1.5; // Matches the 1.5px container on the left
    rightHeight += 8.0; // SizedBox

    rightHeight += _measureCustomerRow(
      '01 Jan 2026',
      customerValueWidth,
    ); // Temp date string for height
    rightHeight += _measureCustomerRow(
      quotation.quotationNumber.isNotEmpty ? quotation.quotationNumber : '—',
      customerValueWidth,
    );
    rightHeight += _measureCustomerRow(
      '01 Jan 2026',
      customerValueWidth,
    ); // Temp date string
    rightHeight += _measureCustomerRow('—', customerValueWidth); // Salesman

    totalHeight += math.max(leftHeight, rightHeight);

    totalHeight += 16.0; // SizedBox before products

    return totalHeight;
  }

  static double _measureCompanyRow(
    String value,
    double valueWidth, {
    int maxLines = 1,
  }) {
    // The height of the row is dominated by the value text, plus 2.0 padding bottom.
    // The label is always 1 line.
    final valueHeight = _measureText(
      value,
      QuotationDocumentTheme.small,
      valueWidth,
      maxLines: maxLines,
    );
    final labelHeight = _measureText(
      'LABEL',
      QuotationDocumentTheme.small,
      100,
    );
    return math.max(labelHeight, valueHeight) + 2.0;
  }

  static double _measureCustomerRow(String value, double valueWidth) {
    // Value text style is smallBold, max 2 lines
    final valueHeight = _measureText(
      value,
      QuotationDocumentTheme.smallBold,
      valueWidth,
      maxLines: 2,
    );
    final labelHeight = _measureText('LABEL', QuotationDocumentTheme.small, 70);
    return math.max(labelHeight, valueHeight) + 2.0;
  }

  static double _measureText(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }
}
