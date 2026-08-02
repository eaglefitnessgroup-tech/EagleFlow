import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';

import 'dart:typed_data';

class ProductImagePanel extends StatelessWidget {
  final Uint8List? imageBytes;

  const ProductImagePanel({super.key, this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.mutedText,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.primarySoft.withValues(alpha: 0.3),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 64, color: AppColors.mutedText),
      ),
    );
  }
}
