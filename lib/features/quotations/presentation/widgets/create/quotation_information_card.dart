import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationInformationCard extends StatefulWidget {
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

  @override
  State<QuotationInformationCard> createState() => _QuotationInformationCardState();
}

class _QuotationInformationCardState extends State<QuotationInformationCard> {
  bool _isEditing = false;

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
                  initialValue: widget.quotationNumber,
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Date',
                  initialValue: _formatDate(widget.date),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Valid Until',
                  initialValue: _formatDate(widget.validUntil),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Delivery Date',
                  initialValue: _formatDate(widget.expectedDelivery),
                ),
              ] else ...[
                if (_isEditing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Quotation No.',
                          initialValue: widget.quotationNumber,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'Date',
                          initialValue: _formatDate(widget.date),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'Salesperson',
                          initialValue: widget.salespersonId,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Valid Until',
                          initialValue: _formatDate(widget.validUntil),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'Delivery Date',
                          initialValue: _formatDate(widget.expectedDelivery),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem('Quotation No.', widget.quotationNumber)),
                      Expanded(child: _buildSummaryItem('Date', _formatDate(widget.date))),
                      Expanded(child: _buildSummaryItem('Salesperson', widget.salespersonId)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem('Valid Until', _formatDate(widget.validUntil))),
                      Expanded(child: _buildSummaryItem('Delivery Date', _formatDate(widget.expectedDelivery))),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
                child: Text(
                  _isEditing ? 'Done' : 'Edit',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(fontSize: 13, color: AppColors.charcoal, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
