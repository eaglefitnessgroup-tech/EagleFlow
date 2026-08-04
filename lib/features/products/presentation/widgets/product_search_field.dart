import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ProductSearchField extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final bool autoFocus;

  const ProductSearchField({super.key, this.onChanged, this.autoFocus = false});

  @override
  State<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<ProductSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        controller: _controller,
        autofocus: widget.autoFocus,
        textInputAction: TextInputAction.search,
        onChanged: (val) {
          setState(() {});
          widget.onChanged?.call(val);
        },
        decoration: InputDecoration(
          hintText: 'Search by name or code...',
          hintStyle: const TextStyle(color: AppColors.mutedText),
          prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
          suffixIcon: _controller.text.isNotEmpty
              ? Tooltip(
                  message: 'Clear search',
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.mutedText),
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                      widget.onChanged?.call('');
                    },
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
