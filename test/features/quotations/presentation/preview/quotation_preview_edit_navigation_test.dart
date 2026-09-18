import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Edit opens Create Quotation with the same quotation', (
    tester,
  ) async {
    final quotation = Quotation(
      id: 'quotation-id',
      quotationNumber: 'QT-EDIT-001',
      customerInfo: const CustomerInfo(
        name: 'Existing Customer',
        company: 'Existing Company',
        phone: '+971500000000',
        email: 'customer@example.com',
        projectLocation: 'Dubai',
      ),
      salespersonId: 'salesperson-id',
      createdDate: DateTime(2026, 9, 1),
      modifiedDate: DateTime(2026, 9, 2),
      validUntil: DateTime(2026, 9, 16),
      expectedDelivery: DateTime(2026, 9, 20),
      lineItems: const [
        QuotationLineItem(
          id: 'line-item-id',
          productId: 'product-id',
          productCode: 'PRODUCT-001',
          name: 'Existing Product',
          brand: 'Existing Brand',
          unitPrice: 1250,
          quantity: 3,
          discount: 7.5,
          description: 'Existing specification',
        ),
      ],
      charges: const QuotationCharges(
        deliveryCharges: 100,
        installationCharges: 200,
        otherCharges: 50,
        overallDiscount: 25,
        vatPercentage: 5,
      ),
      customerNotes: 'Existing customer notes',
      internalNotes: 'Existing internal notes',
    );
    Object? editArguments;

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/quotation-preview',
        onGenerateRoute: (settings) {
          if (settings.name == '/quotation-preview') {
            return MaterialPageRoute<void>(
              settings: RouteSettings(
                name: settings.name,
                arguments: quotation,
              ),
              builder: (_) => const QuotationPreviewScreen(),
            );
          }
          if (settings.name == '/create-quotation') {
            editArguments = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Text('Create Quotation edit destination'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Create Quotation edit destination'), findsOneWidget);
    expect(editArguments, same(quotation));
  });
}
