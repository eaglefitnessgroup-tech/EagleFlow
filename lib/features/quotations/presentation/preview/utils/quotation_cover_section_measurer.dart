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

    // 1. HEADER
    // Logo is 48px height. Text is ~30px. Wrap will put them on one line (595 width is enough).
    // Height of this row is determined by the logo.
    totalHeight += 48.0;

    // 2. DIVIDER
    totalHeight += 8.0; // SizedBox
    totalHeight += 1.0; // Divider
    totalHeight += 8.0; // SizedBox

    // 3. QUOTATION & COMPANY INFO
    // Two columns in a Wrap. Will fit on one line.
    // Calculate Column 1 (Company Details)
    final companyTitleHeight = _measureText(
      'TL Name:',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final nameHeight = _measureText(
      profile.name,
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );
    final licenseTitleHeight = _measureText(
      'TL / License No.:',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final licenseHeight = _measureText(
      profile.licenseNo,
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );
    final trnTitleHeight = _measureText(
      'TRN:',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final trnHeight = _measureText(
      profile.trn,
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );
    final addressTitleHeight = _measureText(
      'Address:',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final addressHeight = _measureText(
      profile.address,
      QuotationDocumentTheme.body,
      contentWidth / 2,
      maxLines: 3,
    );
    final emailTitleHeight = _measureText(
      'Email:',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final emailHeight = _measureText(
      profile.email,
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );
    final mobileTitleHeight = _measureText(
      'Telephone:',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final mobileHeight = _measureText(
      profile.mobile,
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );

    final col1Height =
        companyTitleHeight +
        nameHeight +
        4.0 +
        licenseTitleHeight +
        licenseHeight +
        4.0 +
        trnTitleHeight +
        trnHeight +
        4.0 +
        addressTitleHeight +
        addressHeight +
        4.0 +
        emailTitleHeight +
        emailHeight +
        4.0 +
        mobileTitleHeight +
        mobileHeight;

    // Calculate Column 2 (Document Info)
    final docTitleHeight = _measureText(
      'DOCUMENT INFO',
      QuotationDocumentTheme.smallBold,
      contentWidth / 2,
    );
    final dateHeight = _measureText(
      'Date: 01 Jan 2026',
      QuotationDocumentTheme.body,
      contentWidth / 2,
    ); // Approximate text length
    final validHeight = _measureText(
      'Valid Until: 01 Jan 2026',
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );
    final refHeight = _measureText(
      'Ref No: ${quotation.quotationNumber.isNotEmpty ? quotation.quotationNumber : "—"}',
      QuotationDocumentTheme.body,
      contentWidth / 2,
    );
    final col2Height =
        docTitleHeight + 8.0 + dateHeight + validHeight + refHeight;

    totalHeight += math.max(col1Height, col2Height);

    totalHeight += 8.0; // SizedBox

    // 4. CUSTOMER INFO
    totalHeight += _measureText(
      'PREPARED FOR',
      QuotationDocumentTheme.smallBold,
      contentWidth,
    );
    totalHeight += 8.0; // SizedBox
    totalHeight += _measureText(
      quotation.customerInfo.name.isNotEmpty
          ? quotation.customerInfo.name
          : '—',
      QuotationDocumentTheme.h2,
      contentWidth,
      maxLines: 2,
    );
    totalHeight += 4.0; // SizedBox
    totalHeight += _measureText(
      'Company: ${quotation.customerInfo.company.isNotEmpty ? quotation.customerInfo.company : "—"}',
      QuotationDocumentTheme.body,
      contentWidth,
      maxLines: 2,
    );
    totalHeight += _measureText(
      'Contact: ${quotation.customerInfo.phone.isNotEmpty ? quotation.customerInfo.phone : "—"}',
      QuotationDocumentTheme.body,
      contentWidth,
      maxLines: 1,
    );
    totalHeight += _measureText(
      'Email: ${quotation.customerInfo.email.isNotEmpty ? quotation.customerInfo.email : "—"}',
      QuotationDocumentTheme.body,
      contentWidth,
      maxLines: 1,
    );
    totalHeight += _measureText(
      'Project / Location: ${quotation.customerInfo.projectLocation.isNotEmpty ? quotation.customerInfo.projectLocation : "—"}',
      QuotationDocumentTheme.body,
      contentWidth,
      maxLines: 2,
    );

    totalHeight += 8.0; // SizedBox before products

    return totalHeight;
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
