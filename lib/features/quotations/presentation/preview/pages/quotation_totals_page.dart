import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../components/quotation_totals_block.dart';

class QuotationTotalsPage extends StatelessWidget {
  final Quotation quotation;

  const QuotationTotalsPage({super.key, required this.quotation});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [QuotationTotalsBlock(quotation: quotation)],
    );
  }
}
