import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';

import '../../../domain/product.dart';
import '../product_image.dart';

class ProductImagePanel extends StatelessWidget {
  final Product product;

  const ProductImagePanel({super.key, required this.product});

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
      child: ProductImage(
        product: product,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorIconSize: 64,
      ),
    );
  }
}
