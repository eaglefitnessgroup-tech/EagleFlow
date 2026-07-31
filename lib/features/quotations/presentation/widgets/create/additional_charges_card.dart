import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class AdditionalChargesCard extends StatelessWidget {
  const AdditionalChargesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return _buildCard(
          isMobile,
          title: isMobile ? 'Charges' : 'Additional Charges & Discount',
          child: Column(
            children: [
              if (isMobile) ...[
                _buildNumberField('Delivery'),
                const SizedBox(height: 16),
                _buildNumberField('Installation'),
                const SizedBox(height: 16),
                _buildNumberField('Other Charges'),
                const SizedBox(height: 16),
                _buildNumberField('Discount'),
                const SizedBox(height: 16),
                _buildNumberField('VAT %', initialValue: '5.0'),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _buildNumberField('Delivery')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildNumberField('Installation')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildNumberField('Other Charges')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildNumberField('Discount')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNumberField('VAT %', initialValue: '5.0'),
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

  Widget _buildNumberField(String label, {String? initialValue}) {
    return TextField(
      controller: initialValue != null
          ? TextEditingController(text: initialValue)
          : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          borderSide: const BorderSide(color: AppColors.primaryBlue),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
