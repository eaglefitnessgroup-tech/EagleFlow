import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';

class ProductDescriptionSection extends StatelessWidget {
  final String? description;

  const ProductDescriptionSection({super.key, this.description});

  @override
  Widget build(BuildContext context) {
    if (description == null || description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description!,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }
}
