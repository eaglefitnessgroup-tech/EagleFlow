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
  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.charcoal, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Quotation Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  label: 'Quotation No.',
                  initialValue: widget.quotationNumber,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  label: 'Quotation Date',
                  isRequired: true,
                  initialValue: _formatDate(widget.date),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  label: 'Valid Until',
                  isRequired: true,
                  initialValue: _formatDate(widget.validUntil),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Sales Person',
                  value: widget.salespersonId.isNotEmpty ? widget.salespersonId : null,
                  hint: 'Select...',
                  items: widget.salespersonId.isNotEmpty ? [widget.salespersonId] : [],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String initialValue,
    bool isRequired = false,
    bool readOnly = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.charcoal),
            children: isRequired
                ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: initialValue),
          readOnly: readOnly,
          decoration: InputDecoration(
            suffixIcon: icon != null ? Icon(icon, color: AppColors.mutedText, size: 16) : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: readOnly ? AppColors.border : AppColors.primaryBlue,
              ),
            ),
            filled: true,
            fillColor: readOnly ? AppColors.surface : Colors.white,
          ),
          style: TextStyle(
            fontSize: 13,
            color: readOnly ? AppColors.mutedText : AppColors.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    String? displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.charcoal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.mutedText, size: 18),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primaryBlue),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          hint: Text(
            hint,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item == value && displayText != null ? displayText : item,
                style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: (val) {},
        ),
      ],
    );
  }
}
