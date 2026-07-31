import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class CustomerInformationCard extends StatelessWidget {
  const CustomerInformationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return _buildCard(
          isMobile,
          title: isMobile ? 'Customer' : 'Customer Information',
          child: Column(
            children: [
              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField('Customer Name'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField('Company'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField('Phone'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField('Email'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildTextField('Project / Location'),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _buildTextField('Customer Name')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Company')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Phone')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Email')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Project / Location'),
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

  Widget _buildTextField(String label) {
    return TextField(
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
        fillColor: AppColors.surface,
      ),
    );
  }
}
