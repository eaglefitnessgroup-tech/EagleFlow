import 'package:flutter/material.dart';
import '../quotation_document_theme.dart';
import '../components/quotation_document_header.dart';

class QuotationTermsPage extends StatelessWidget {
  const QuotationTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuotationDocumentHeader(),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                'Payment Terms',
                '• 50% advance payment required to confirm the order.\n'
                    '• 50% balance payment required prior to delivery/installation.',
              ),
              _buildSection(
                'Accepted Payment Methods',
                '• Bank Transfer (Details provided on the next page).\n'
                    '• Cheque (Subject to clearance before delivery).',
              ),
              _buildSection(
                'Additional Payment Options',
                '• Credit Card payments are subject to a 2.5% surcharge.\n'
                    '• Post-dated cheques are not accepted unless pre-approved in writing.',
              ),
              _buildSection(
                'Delivery and Installation',
                '• Standard delivery timeline is 7-14 working days from receipt of advance payment.\n'
                    '• Site must be ready and cleared for installation prior to our team\'s arrival.\n'
                    '• Additional charges apply for hoisting or delivery above ground floor without service elevator access.',
              ),
              _buildSection(
                'Product Warranty / Services',
                '• All equipment carries a standard 1-year warranty against manufacturing defects.\n'
                    '• Warranty does not cover normal wear and tear, misuse, or damage caused by improper maintenance.\n'
                    '• First preventative maintenance visit is complimentary within the first 6 months.',
              ),
              _buildSection(
                'Returns and Refunds',
                '• Custom orders and special import items cannot be cancelled or refunded.\n'
                    '• Standard items may be returned within 7 days in original, unopened packaging, subject to a 20% restocking fee.',
              ),
              _buildSection(
                'Acknowledgement & Acceptance',
                '• By issuing a Purchase Order against this quotation, the buyer agrees to all stated terms and conditions.\n'
                    '• Quotation is valid for 15 days from the date of issue.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: QuotationDocumentTheme.h3),
          const SizedBox(height: 8),
          Text(content, style: QuotationDocumentTheme.body),
        ],
      ),
    );
  }
}
