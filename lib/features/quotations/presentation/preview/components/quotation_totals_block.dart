import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../../../application/quotation_calculator.dart';
import '../../../application/quotation_amount_in_words_formatter.dart';
import '../quotation_document_theme.dart';
import '../quotation_document_formatters.dart';
import '../quotation_layout_spec.dart';

class QuotationTotalsBlock extends StatelessWidget {
  final Quotation quotation;

  const QuotationTotalsBlock({super.key, required this.quotation});

  @override
  Widget build(BuildContext context) {
    final subtotal = QuotationCalculator.calculateSubtotal(quotation.lineItems);
    final vat = QuotationCalculator.calculateVAT(
      quotation.lineItems,
      quotation.charges,
    );
    final grandTotal = QuotationCalculator.calculateGrandTotal(
      quotation.lineItems,
      quotation.charges,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 16, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildRow('Subtotal', subtotal),
          if (quotation.charges.deliveryCharges > 0)
            _buildRow('Delivery Charges', quotation.charges.deliveryCharges),
          if (quotation.charges.installationCharges > 0)
            _buildRow(
              'Installation Charges',
              quotation.charges.installationCharges,
            ),
          if (quotation.charges.otherCharges > 0)
            _buildRow('Other Charges', quotation.charges.otherCharges),
          if (quotation.charges.overallDiscount > 0)
            _buildRow(
              'Overall Discount',
              -quotation.charges.overallDiscount,
              isDiscount: true,
            ),
          _buildRow('VAT (${quotation.charges.vatPercentage}%)', vat),
          const SizedBox(height: 2),
          const Divider(
            color: QuotationDocumentTheme.border,
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 31,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Grand Total',
                  style: QuotationDocumentTheme.h3,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      QuotationDocumentFormatters.formatCurrency(grandTotal),
                      style: QuotationDocumentTheme.h2.copyWith(
                        color: QuotationDocumentTheme.navy,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: QuotationLayoutSpec.amountInWordsHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AMOUNT IN WORDS',
                  style: QuotationDocumentTheme.smallBold.copyWith(
                    color: QuotationDocumentTheme.textMuted,
                    fontSize: 7.5,
                    letterSpacing: 0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  QuotationAmountInWordsFormatter.format(grandTotal),
                  style: QuotationDocumentTheme.small.copyWith(
                    color: QuotationDocumentTheme.textMain,
                    fontSize: 8,
                    height: 1.05,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double amount, {bool isDiscount = false}) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: QuotationDocumentTheme.body,
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: Text(
              isDiscount
                  ? '- ${QuotationDocumentFormatters.formatCurrency(amount.abs())}'
                  : QuotationDocumentFormatters.formatCurrency(amount),
              style: isDiscount
                  ? QuotationDocumentTheme.body.copyWith(color: Colors.red)
                  : QuotationDocumentTheme.bodyBold,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
