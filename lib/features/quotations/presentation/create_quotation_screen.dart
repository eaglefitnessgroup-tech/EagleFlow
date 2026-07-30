import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';

class CreateQuotationScreen extends StatelessWidget {
  const CreateQuotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Quotation')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Quotation Form Placeholder'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.quotationPreview);
              },
              child: const Text('Preview Quotation'),
            ),
          ],
        ),
      ),
    );
  }
}
