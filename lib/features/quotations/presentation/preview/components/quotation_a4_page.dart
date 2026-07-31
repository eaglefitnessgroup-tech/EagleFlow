import 'package:flutter/material.dart';
import '../quotation_layout_spec.dart';
import '../quotation_document_theme.dart';

class QuotationA4Page extends StatelessWidget {
  final Widget child;

  const QuotationA4Page({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: QuotationLayoutSpec.a4LogicalWidth,
      height: QuotationLayoutSpec.a4LogicalHeight,
      child: Container(
        decoration: BoxDecoration(
          color: QuotationDocumentTheme.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // The clip prevents any child content from spilling outside the page
        clipBehavior: Clip.hardEdge,
        child: Padding(padding: QuotationLayoutSpec.pageMargin, child: child),
      ),
    );
  }
}
