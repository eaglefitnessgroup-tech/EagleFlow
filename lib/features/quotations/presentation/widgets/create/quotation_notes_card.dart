import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationNotesCard extends StatefulWidget {
  final String initialCustomerNotes;
  final String initialInternalNotes;
  final ValueChanged<String>? onCustomerNotesChanged;
  final ValueChanged<String>? onInternalNotesChanged;

  const QuotationNotesCard({
    super.key,
    this.initialCustomerNotes = '',
    this.initialInternalNotes = '',
    this.onCustomerNotesChanged,
    this.onInternalNotesChanged,
  });

  @override
  State<QuotationNotesCard> createState() => _QuotationNotesCardState();
}

class _QuotationNotesCardState extends State<QuotationNotesCard> {
  late final TextEditingController _customerNotesCtrl;
  late final TextEditingController _internalNotesCtrl;

  @override
  void initState() {
    super.initState();
    _customerNotesCtrl = TextEditingController(
      text: widget.initialCustomerNotes,
    );
    _internalNotesCtrl = TextEditingController(
      text: widget.initialInternalNotes,
    );
  }

  @override
  void didUpdateWidget(QuotationNotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCustomerNotes != widget.initialCustomerNotes &&
        _customerNotesCtrl.text != widget.initialCustomerNotes) {
      _customerNotesCtrl.text = widget.initialCustomerNotes;
    }
    if (oldWidget.initialInternalNotes != widget.initialInternalNotes &&
        _internalNotesCtrl.text != widget.initialInternalNotes) {
      _internalNotesCtrl.text = widget.initialInternalNotes;
    }
  }

  @override
  void dispose() {
    _customerNotesCtrl.dispose();
    _internalNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          children: [
            _buildCard(
              isMobile,
              title: 'Customer Notes',
              subtitle: 'These notes will be printed on the quotation PDF.',
              child: _buildTextArea(
                'Enter notes for the customer...',
                _customerNotesCtrl,
                widget.onCustomerNotesChanged,
              ),
            ),
            const SizedBox(height: 20),
            _buildCard(
              isMobile,
              title: 'Internal Notes',
              subtitle:
                  'These notes are for internal use only and will not be printed.',
              child: _buildTextArea(
                'Enter internal notes...',
                _internalNotesCtrl,
                widget.onInternalNotesChanged,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(
    bool isMobile, {
    required String title,
    required String subtitle,
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextArea(
    String hint,
    TextEditingController controller,
    ValueChanged<String>? onChanged,
  ) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 5,
      maxLines: 7,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mutedText),
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
          borderSide: const BorderSide(color: AppColors.primaryBlue),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
