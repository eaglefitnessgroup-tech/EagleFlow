import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ProductSearchField extends StatelessWidget {
  final ValueChanged<String>? onChanged;

  const ProductSearchField({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Search by name or code...',
          hintStyle: TextStyle(color: AppColors.mutedText),
          prefixIcon: Icon(Icons.search, color: AppColors.mutedText),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
