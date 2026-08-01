import 'package:flutter/material.dart';
import '../../../../../core/models/company_profile.dart';
import '../quotation_document_theme.dart';
import '../components/quotation_document_header.dart';

class QuotationBankDetailsPage extends StatelessWidget {
  const QuotationBankDetailsPage({super.key});

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
              Text(
                'Please remit payment to one of the following accounts:',
                style: QuotationDocumentTheme.body,
              ),
              const SizedBox(height: 32),

              _buildBankCard(
                bankName: 'Mashreq Bank',
                accountName: CompanyProfile.defaultProfile.legalName,
                accountNumber: '014529018440',
                iban: 'AE82 0330 0014 5290 1844 0',
                swift: 'MASHAEAD',
                currency: 'AED',
              ),
              const SizedBox(height: 48),

              _buildBankCard(
                bankName: 'FAB / First Abu Dhabi Bank',
                accountName: CompanyProfile.defaultProfile.legalName,
                accountNumber: '1103948839201',
                iban: 'AE12 0240 0011 0394 8839 201',
                swift: 'NBADAEAD',
                currency: 'AED',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankCard({
    required String bankName,
    required String accountName,
    required String accountNumber,
    required String iban,
    required String swift,
    required String currency,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: QuotationDocumentTheme.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bankName,
            style: QuotationDocumentTheme.h2.copyWith(
              color: QuotationDocumentTheme.navy,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: QuotationDocumentTheme.border),
          const SizedBox(height: 16),
          _buildRow('Account Name:', accountName),
          _buildRow('Account Number:', accountNumber),
          _buildRow('IBAN:', iban),
          _buildRow('SWIFT Code:', swift),
          _buildRow('Currency:', currency),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: QuotationDocumentTheme.smallBold.copyWith(
                color: QuotationDocumentTheme.gold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: QuotationDocumentTheme.bodyBold)),
        ],
      ),
    );
  }
}
