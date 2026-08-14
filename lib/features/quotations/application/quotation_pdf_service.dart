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

class QuotationPdfService {
  late pw.Font _fontRegular;
  late pw.Font _fontMedium;
  late pw.Font _fontSemiBold;

  final PdfColor _navy = const PdfColor.fromInt(0xFF0F172A);
  final PdfColor _textMain = const PdfColor.fromInt(0xFF334155);
  final PdfColor _textMuted = const PdfColor.fromInt(0xFF64748B);
  final PdfColor _border = const PdfColor.fromInt(0xFFF1F5F9);
  final PdfColor _red = const PdfColor.fromInt(0xFFF44336);

  Future<Uint8List> generatePdf(Quotation quotation) async {
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

    // 2. Setup Document & Fonts
    final pdf = pw.Document();
    _fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Regular.ttf'));
    _fontMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Medium.ttf'));
    _fontSemiBold = pw.Font.ttf(await rootBundle.load('assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-SemiBold.ttf'));

    // 3. Paginate
    final pages = QuotationPaginator.paginate(quotation);
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
                pageStartIndex += (pages[j] as QuotationProductsPageModel).items.length;
              }
            }

            return pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (pageModel is QuotationProductsPageModel) ...[
                        if (pageModel.hasCover) _buildCoverSection(quotation),
                        if (pageModel.items.isNotEmpty) _buildTableHeader(),
                        ...pageModel.items.asMap().entries.map((entry) {
                          final itemIndex = pageStartIndex + entry.key + 1;
                          return _buildProductRow(itemIndex, entry.value);
                        }),
                        if (pageModel.hasTotals) ...[
                          pw.Spacer(),
                          _buildTotalsBlock(quotation),
                        ],
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

    return await pdf.save();
  }

  pw.Widget _buildHeader() {
    final profile = CompanyProfile.defaultProfile;
    
    // Try to get logo from cache
    final logoBytes = PdfImageLoader.loadAssetSync('assets/logos/logo_head_cropped.png');
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (logoBytes != null)
              pw.Image(pw.MemoryImage(logoBytes), width: 180, height: 42, fit: pw.BoxFit.contain, alignment: pw.Alignment.centerLeft)
            else
              pw.SizedBox(width: 180, height: 42),
            
            pw.SizedBox(width: 16),
            pw.Text(
              profile.website,
              style: pw.TextStyle(
                font: _fontRegular,
                fontSize: 10,
                color: _textMuted,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _border, thickness: 1, height: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildCoverSection(Quotation quotation) {
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
                  _buildCompanyRow('ADDRESS', '${profile.addressLine1}\n${profile.addressLine2}', maxLines: 2),
                  _buildCompanyRow('MOBILE', profile.mobile),
                  _buildCompanyRow('TELEPHONE', profile.telephone),
                  _buildCompanyRow('TRN', profile.trn),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 32),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('QUOTATION TO', style: pw.TextStyle(font: _fontSemiBold, fontSize: 10, color: _navy)),
                  pw.SizedBox(height: 4),
                  pw.Container(width: 130, height: 1.5, color: _navy),
                  pw.SizedBox(height: 8),
                  _buildCustomerRow('CUSTOMER', quotation.customerInfo.name.isNotEmpty ? quotation.customerInfo.name : '-'),
                  _buildCustomerRow('LOCATION', quotation.customerInfo.projectLocation.isNotEmpty ? quotation.customerInfo.projectLocation : '-'),
                  _buildCustomerRow('CONTACT', quotation.customerInfo.phone.isNotEmpty ? quotation.customerInfo.phone : '-'),
                ],
              ),
            ),
            pw.SizedBox(width: 32),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('', style: pw.TextStyle(font: _fontSemiBold, fontSize: 10, color: _navy)),
                  pw.SizedBox(height: 4),
                  pw.SizedBox(height: 1.5),
                  pw.SizedBox(height: 8),
                  _buildCustomerRow('DATE', QuotationDocumentFormatters.formatDate(quotation.createdDate)),
                  _buildCustomerRow('QT NO', quotation.quotationNumber.isNotEmpty ? quotation.quotationNumber : '-'),
                  _buildCustomerRow('EXPIRED', QuotationDocumentFormatters.formatDate(quotation.validUntil)),
                  _buildCustomerRow('SALESMAN', quotation.salespersonId.isNotEmpty ? quotation.salespersonId : '-'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildCompanyRow(String label, String value, {int maxLines = 1}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(font: _fontRegular, fontSize: 10, color: _textMuted)),
          ),
          pw.Text(' : ', style: pw.TextStyle(font: _fontRegular, fontSize: 10, color: _textMuted)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: _fontRegular, fontSize: 10, color: _textMuted),
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: pw.TextStyle(font: _fontRegular, fontSize: 10, color: _textMuted)),
          ),
          pw.Text(' : ', style: pw.TextStyle(font: _fontRegular, fontSize: 10, color: _textMuted)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: _fontSemiBold, fontSize: 10, color: _navy),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableHeader() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _navy, width: 1.5),
          bottom: pw.BorderSide(color: _border, width: 1.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: pw.Row(
        children: [
          _buildTableCell('No.', QuotationLayoutSpec.columnFlex['sno']!, center: true),
          _buildTableCell('Photo', QuotationLayoutSpec.columnFlex['photo']!, center: true),
          _buildTableCell('Product', QuotationLayoutSpec.columnFlex['product']!),
          _buildTableCell('Qty', QuotationLayoutSpec.columnFlex['qty']!, center: true),
          _buildTableCell('Price', QuotationLayoutSpec.columnFlex['unitPrice']!, right: true),
          _buildTableCell('Disc.', QuotationLayoutSpec.columnFlex['discount']!, right: true),
          _buildTableCell('Amount', QuotationLayoutSpec.columnFlex['amount']!, right: true),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, int flex, {bool center = false, bool right = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Align(
          alignment: center ? pw.Alignment.center : (right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: _fontSemiBold, fontSize: 10, color: _navy),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildProductRow(int index, QuotationLineItem item) {
    final lineTotal = QuotationCalculator.calculateLineTotal(item.unitPrice, item.quantity, item.discount);
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
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _border, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildCell(index.toString(), QuotationLayoutSpec.columnFlex['sno']!, center: true),
          
          pw.Expanded(
            flex: QuotationLayoutSpec.columnFlex['photo']!,
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
                  : pw.SizedBox(width: QuotationLayoutSpec.productImageSize, height: QuotationLayoutSpec.productImageSize),
            ),
          ),

          pw.Expanded(
            flex: QuotationLayoutSpec.columnFlex['product']!,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.name,
                    style: pw.TextStyle(font: _fontSemiBold, fontSize: 12, color: _navy),
                    maxLines: 2,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Code: ${item.productCode ?? "-"} | Brand: ${item.brand.isNotEmpty ? item.brand : "-"}',
                    style: pw.TextStyle(font: _fontMedium, fontSize: 10, color: _textMuted),
                    maxLines: 1,
                  ),
                  if (item.description != null && item.description!.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        item.description!,
                        style: pw.TextStyle(font: _fontRegular, fontSize: 10, color: _textMain, lineSpacing: 1.3),
                        maxLines: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),

          _buildCell(item.quantity.toString(), QuotationLayoutSpec.columnFlex['qty']!, center: true),
          _buildCell(QuotationDocumentFormatters.formatCurrency(item.unitPrice), QuotationLayoutSpec.columnFlex['unitPrice']!, right: true),
          _buildCell(
            item.discount > 0
                ? '${item.discount.truncateToDouble() == item.discount ? item.discount.toInt() : item.discount}%'
                : '-',
            QuotationLayoutSpec.columnFlex['discount']!,
            right: true,
          ),
          _buildCell(QuotationDocumentFormatters.formatCurrency(lineTotal), QuotationLayoutSpec.columnFlex['amount']!, right: true, bold: true),
        ],
      ),
    );
  }

  pw.Widget _buildCell(String text, int flex, {bool center = false, bool right = false, bool bold = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Align(
          alignment: center ? pw.Alignment.center : (right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: bold ? _fontSemiBold : _fontRegular,
              fontSize: 12,
              color: bold ? _navy : _textMain,
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildTotalsBlock(Quotation quotation) {
    final subtotal = QuotationCalculator.calculateSubtotal(quotation.lineItems);
    final vat = QuotationCalculator.calculateVAT(subtotal, quotation.charges);
    final grandTotal = QuotationCalculator.calculateGrandTotal(subtotal, quotation.charges);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildTotalRow('Subtotal', subtotal),
          if (quotation.charges.deliveryCharges > 0)
            _buildTotalRow('Delivery Charges', quotation.charges.deliveryCharges),
          if (quotation.charges.installationCharges > 0)
            _buildTotalRow('Installation Charges', quotation.charges.installationCharges),
          if (quotation.charges.otherCharges > 0)
            _buildTotalRow('Other Charges', quotation.charges.otherCharges),
          if (quotation.charges.overallDiscount > 0)
            _buildTotalRow('Overall Discount', -quotation.charges.overallDiscount, isDiscount: true),
          _buildTotalRow('VAT (${quotation.charges.vatPercentage}%)', vat),
          
          pw.SizedBox(height: 4),
          pw.Divider(color: _border, thickness: 1, height: 1),
          pw.SizedBox(height: 4),
          
          pw.SizedBox(
            height: 31,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Grand Total', style: pw.TextStyle(font: _fontSemiBold, fontSize: 14, color: _navy)),
                pw.SizedBox(width: 16),
                pw.Container(
                  width: 140,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    QuotationDocumentFormatters.formatCurrency(grandTotal),
                    style: pw.TextStyle(font: _fontSemiBold, fontSize: 22, color: _navy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(String label, double amount, {bool isDiscount = false}) {
    return pw.SizedBox(
      height: 20,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: _fontRegular, fontSize: 12, color: _textMain),
          ),
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
        pw.Text('BANK ACCOUNT DETAILS', style: pw.TextStyle(font: _fontSemiBold, fontSize: 10.5, color: _navy, letterSpacing: 0.6)),
        pw.SizedBox(height: 2),
        pw.Container(width: 55, height: 1.5, color: _navy),
        pw.SizedBox(height: 8),

        pw.Table(
          border: pw.TableBorder(verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 1)),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            _buildBankTableRow('BANK NAME', 'Mashreq Bank', 'FAB / First Abu Dhabi Bank'),
            _buildBankTableRow('ACCOUNT NAME', CompanyProfile.defaultProfile.legalName, CompanyProfile.defaultProfile.legalName),
            _buildBankTableRow('ACCOUNT NUMBER', '014529018440', '1103948839201'),
            _buildBankTableRow('IBAN NUMBER', 'AE82 0330 0014 5290 1844 0', 'AE12 0240 0011 0394 8839 201'),
            _buildBankTableRow('SWIFT CODE', 'MASHAEAD', 'NBADAEAD'),
            _buildBankTableRow('CURRENCY', 'AED', 'AED'),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Text('Terms & Conditions', style: pw.TextStyle(font: _fontSemiBold, fontSize: 22, color: _navy)),
        pw.SizedBox(height: 12),

        _buildTermsSection('Payment Terms', '• 50% advance payment required to confirm the order.\n• 50% balance payment required prior to delivery/installation.'),
        _buildTermsSection('Accepted Payment Methods', '• Bank Transfer (Details provided above).\n• Cheque (Subject to clearance before delivery).'),
        _buildTermsSection('Additional Payment Options', '• Credit Card payments are subject to a 2.5% surcharge.\n• Post-dated cheques are not accepted unless pre-approved in writing.'),
        _buildTermsSection('Delivery and Installation', '• Standard delivery timeline is 7-14 working days from receipt of advance payment.\n• Site must be ready and cleared for installation prior to our team\'s arrival.\n• Additional charges apply for hoisting or delivery above ground floor without service elevator access.'),
        _buildTermsSection('Product Warranty / Services', '• All equipment carries a standard 1-year warranty against manufacturing defects.\n• Warranty does not cover normal wear and tear, misuse, or damage caused by improper maintenance.\n• First preventative maintenance visit is complimentary within the first 6 months.'),
        _buildTermsSection('Returns and Refunds', '• Custom orders and special import items cannot be cancelled or refunded.\n• Standard items may be returned within 7 days in original, unopened packaging, subject to a 20% restocking charge.'),
        _buildTermsSection('Acknowledgement & Acceptance', '• By issuing a Purchase Order against this quotation, the buyer agrees to all stated terms and conditions.\n• Quotation is valid for 15 days from the date of issue.'),

        if (quotation.customerNotes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text('Customer Notes', style: pw.TextStyle(font: _fontSemiBold, fontSize: 22, color: _navy)),
          pw.SizedBox(height: 12),
          pw.Text(
            quotation.customerNotes.trim(),
            style: pw.TextStyle(font: _fontRegular, fontSize: 9.6, color: _textMuted, lineSpacing: 1.3),
          ),
        ],
      ],
    );
  }

  pw.TableRow _buildBankTableRow(String label, String leftValue, String rightValue) {
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
            style: pw.TextStyle(font: _fontRegular, fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        pw.Text(' :  ', style: pw.TextStyle(font: _fontSemiBold, fontSize: 9, color: _navy)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: _fontSemiBold, fontSize: 9, color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTermsSection(String title, String content) {
    final lines = content.split('\n');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8.0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: _fontSemiBold, fontSize: 10, color: _navy)),
          pw.SizedBox(height: 2),
          ...lines.map((line) {
            String text = line.trim();
            bool hasBullet = false;
            if (text.startsWith('• ')) {
              hasBullet = true;
              text = text.substring(2);
            } else if (text.startsWith('- ')) {
              hasBullet = true;
              text = text.substring(2);
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (hasBullet)
                    pw.Container(
                      width: 10,
                      padding: const pw.EdgeInsets.only(top: 3, right: 4),
                      child: pw.Container(
                        width: 3,
                        height: 3,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: _textMuted,
                        ),
                      ),
                    ),
                  pw.Expanded(
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(font: _fontRegular, fontSize: 9.6, color: _textMuted, lineSpacing: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }),
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
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Showroom No. SH03, Industrial Area 18, Maleha Road, Sharjah, U.A.E.  ',
                style: pw.TextStyle(font: _fontMedium, fontSize: 8, color: PdfColors.grey600),
              ),
              pw.SvgImage(
                svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M6.54 5c.06.89.21 1.76.45 2.59l-1.2 1.2c-.41-1.2-.67-2.47-.76-3.79h1.51m9.86 12.02c.85.24 1.72.39 2.6.45v1.49c-1.32-.09-2.59-.35-3.8-.75l1.2-1.19M7.5 3H4c-.55 0-1 .45-1 1 0 9.39 7.61 17 17 17 .55 0 1-.45 1-1v-3.49c0-.55-.45-1-1-1-1.24 0-2.45-.2-3.57-.57-.1-.04-.21-.05-.31-.05-.26 0-.51.1-.71.29l-2.2 2.2c-2.83-1.45-5.15-3.76-6.59-6.59l2.2-2.2c.28-.28.36-.67.25-1.02C8.7 6.45 8.5 5.25 8.5 4c0-.55-.45-1-1-1z" fill="#757575"/></svg>',
                width: 10,
                height: 10,
              ),
              pw.Text(
                '  06 532 2336',
                style: pw.TextStyle(font: _fontMedium, fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
