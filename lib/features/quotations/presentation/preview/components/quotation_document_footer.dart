import 'package:flutter/material.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';

class QuotationDocumentFooter extends StatelessWidget {
  const QuotationDocumentFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: QuotationLayoutSpec.footerHeight,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Divider(
            color: QuotationDocumentTheme.border,
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Showroom No. SH03, Industrial Area 18, Maleha Road, Sharjah, U.A.E.  ',
                  style: QuotationDocumentTheme.small.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 8,
                  ),
                  maxLines: 1,
                ),
                Icon(
                  Icons.phone_outlined,
                  size: 10,
                  color: Colors.grey.shade600,
                ),
                Text(
                  '  06 532 2336',
                  style: QuotationDocumentTheme.small.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 8,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
