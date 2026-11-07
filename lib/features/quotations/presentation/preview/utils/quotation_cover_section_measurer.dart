import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/models/company_profile.dart';
import '../../../domain/quotation.dart';
import '../quotation_document_formatters.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';

class QuotationCoverSectionMeasurer {
  /// Measures the logical cover height using the same widths, typography, and
  /// spacing as the Flutter and PDF renderers.
  static double measureHeight(Quotation quotation, {String? salespersonName}) {
    final contentWidth = QuotationLayoutSpec.pageContentWidth;

    final headerHeight =
        QuotationLayoutSpec.documentHeaderLogoHeight +
        (QuotationLayoutSpec.documentHeaderVerticalSpacing * 2) +
        QuotationDocumentTheme.dividerThickness;

    final customerWidth =
        contentWidth -
        QuotationLayoutSpec.coverCustomerColumnSpacing -
        QuotationLayoutSpec.coverDocumentColumnWidth;
    final customerHeight = _measureCustomerColumn(quotation, customerWidth);
    final documentHeight = _measureDocumentColumn(
      quotation,
      QuotationLayoutSpec.coverDocumentColumnWidth,
      salespersonName: salespersonName,
    );

    return headerHeight +
        measureCompanyDetailsHeight() +
        QuotationLayoutSpec.coverCompanyToCustomerSpacing +
        math.max(customerHeight, documentHeight) +
        QuotationLayoutSpec.coverBottomSpacing;
  }

  static double measureCompanyDetailsHeight() {
    final profile = CompanyProfile.defaultProfile;
    final style = QuotationDocumentTheme.small.copyWith(
      fontSize: QuotationLayoutSpec.coverCompanyFontSize,
    );
    final separatorWidth = _measureTextWidth(' : ', style);
    final valueWidth =
        QuotationLayoutSpec.pageContentWidth -
        QuotationLayoutSpec.coverCompanyLabelWidth -
        separatorWidth;

    return _measureCompanyRow(profile.licenseNumber, valueWidth, style) +
        _measureCompanyRow(profile.legalName, valueWidth, style) +
        _measureCompanyRow(
          '${profile.addressLine1}\n${profile.addressLine2}',
          valueWidth,
          style,
          maxLines: 2,
        ) +
        _measureCompanyRow(profile.mobile, valueWidth, style) +
        _measureCompanyRow(profile.telephone, valueWidth, style) +
        _measureCompanyRow(profile.trn, valueWidth, style);
  }

  static double _measureCustomerColumn(
    Quotation quotation,
    double columnWidth,
  ) {
    final valueWidth = _customerValueWidth(columnWidth);
    return _customerColumnHeadingHeight +
        _measureCustomerRow(
          quotation.customerInfo.name.isNotEmpty
              ? quotation.customerInfo.name
              : '—',
          valueWidth,
        ) +
        _measureCustomerRow(
          quotation.customerInfo.projectLocation.isNotEmpty
              ? quotation.customerInfo.projectLocation
              : '—',
          valueWidth,
        ) +
        _measureCustomerRow(
          quotation.customerInfo.phone.isNotEmpty
              ? quotation.customerInfo.phone
              : '—',
          valueWidth,
        );
  }

  static double _measureDocumentColumn(
    Quotation quotation,
    double columnWidth, {
    String? salespersonName,
  }) {
    final valueWidth = _customerValueWidth(columnWidth);
    final displayedSalesperson = salespersonName?.isNotEmpty == true
        ? salespersonName!
        : quotation.salespersonId.isNotEmpty
        ? quotation.salespersonId
        : '—';

    return _customerColumnHeadingHeight +
        _measureCustomerRow(
          QuotationDocumentFormatters.formatDate(quotation.createdDate),
          valueWidth,
        ) +
        _measureCustomerRow(
          quotation.displayQuotationNumber.isNotEmpty
              ? quotation.displayQuotationNumber
              : '—',
          valueWidth,
        ) +
        _measureCustomerRow(
          QuotationDocumentFormatters.formatDate(quotation.validUntil),
          valueWidth,
        ) +
        _measureCustomerRow(displayedSalesperson, valueWidth);
  }

  static double get _customerColumnHeadingHeight =>
      QuotationLayoutSpec.coverCustomerHeadingHeight +
      QuotationLayoutSpec.coverCustomerHeadingSpacing +
      QuotationLayoutSpec.coverCustomerDividerHeight +
      QuotationLayoutSpec.coverCustomerDividerSpacing;

  static double _customerValueWidth(double columnWidth) {
    final separatorWidth = _measureTextWidth(
      ' : ',
      QuotationDocumentTheme.small,
    );
    return columnWidth -
        QuotationLayoutSpec.coverCustomerLabelWidth -
        separatorWidth;
  }

  static double _measureCompanyRow(
    String value,
    double valueWidth,
    TextStyle style, {
    int maxLines = 1,
  }) {
    final valueHeight = _measureText(
      value,
      style,
      valueWidth,
      maxLines: maxLines,
    );
    final labelHeight = _measureText(
      'LABEL',
      style,
      QuotationLayoutSpec.coverCompanyLabelWidth,
    );
    return math.max(labelHeight, valueHeight) +
        QuotationLayoutSpec.coverCompanyRowBottomPadding;
  }

  static double _measureCustomerRow(String value, double valueWidth) {
    final valueHeight = _measureText(
      value,
      QuotationDocumentTheme.smallBold,
      valueWidth,
      maxLines: 2,
    );
    final labelHeight = _measureText(
      'LABEL',
      QuotationDocumentTheme.small,
      QuotationLayoutSpec.coverCustomerLabelWidth,
    );
    return math.max(labelHeight, valueHeight) +
        QuotationLayoutSpec.coverCustomerRowBottomPadding;
  }

  static double _measureText(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  static double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }
}
