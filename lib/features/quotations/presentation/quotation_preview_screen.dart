import 'package:flutter/material.dart';

class QuotationPreviewScreen extends StatelessWidget {
  const QuotationPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quotation Preview')),
      body: const Center(
        child: Text('Generate PDF & Share (WhatsApp/Email) Placeholder'),
      ),
    );
  }
}
