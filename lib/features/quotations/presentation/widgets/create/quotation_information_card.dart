import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationInformationCard extends StatelessWidget {
  final String quotationNumber;
  final String salespersonId;
  final DateTime date;
  final DateTime validUntil;
  final DateTime expectedDelivery;

  const QuotationInformationCard({
    super.key,
    required this.quotationNumber,
    required this.salespersonId,
    required this.date,
    required this.validUntil,
    required this.expectedDelivery,
  });

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return _buildCard(
          isMobile,
          title: isMobile ? 'Quotation' : 'Quotation Information',
          child: Column(
            children: [
              if (isMobile) ...[
                _buildTextField(
                  'Quotation No.',
                  initialValue: quotationNumber,
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Date',
                  initialValue: _formatDate(date),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Valid Until',
                  initialValue: _formatDate(validUntil),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Delivery Date',
                  initialValue: _formatDate(expectedDelivery),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Quotation No.',
                        initialValue: quotationNumber,
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        'Date',
                        initialValue: _formatDate(date),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Valid Until',
                        initialValue: _formatDate(validUntil),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        'Delivery Date',
                        initialValue: _formatDate(expectedDelivery),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                'Salesperson',
                initialValue: salespersonId,
                readOnly: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    bool isMobile, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    String? initialValue,
    bool readOnly = false,
  }) {
    return TextField(
      controller: initialValue != null
          ? TextEditingController(text: initialValue)
          : null,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: readOnly ? AppColors.border : AppColors.primaryBlue,
          ),
        ),
        filled: true,
        fillColor: readOnly ? AppColors.surface : Colors.white,
      ),
    );
  }
}
