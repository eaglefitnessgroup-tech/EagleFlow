import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Create to Preview to Edit reuses the originating Create route and returns latest data',
    (tester) async {
      final controller = QuotationController(_quotation());
      Quotation? returnedQuotation;
      var createRouteBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/create-quotation',
          routes: {
            '/create-quotation': (context) {
              createRouteBuildCount++;
              return Scaffold(
                body: Column(
                  children: [
                    const Text('Originating Create Quotation'),
                    FilledButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/quotation-preview',
                          arguments: controller,
                        );
                        if (result is Quotation) {
                          returnedQuotation = result;
                        }
                      },
                      child: const Text('Open Preview'),
                    ),
                  ],
                ),
              );
            },
            '/quotation-preview': (_) => const QuotationPreviewScreen(),
          },
        ),
      );

      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      final latestQuotation = controller.quotation.copyWith(
        customerNotes: 'Latest customer notes',
        internalNotes: 'Latest internal notes',
      );
      controller.loadQuotation(latestQuotation);
      await tester.pump();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Originating Create Quotation'), findsOneWidget);
      expect(find.byType(QuotationPreviewScreen), findsNothing);
      expect(createRouteBuildCount, 1);
      expect(returnedQuotation, same(latestQuotation));
      expect(returnedQuotation!.id, 'quotation-id');
      expect(returnedQuotation!.quotationNumber, 'QT-EDIT-001');
      expect(returnedQuotation!.customerInfo.name, 'Existing Customer');
      expect(returnedQuotation!.salespersonId, 'salesperson-id');
      expect(returnedQuotation!.createdDate, DateTime(2026, 9, 1));
      expect(returnedQuotation!.validUntil, DateTime(2026, 9, 16));
      expect(returnedQuotation!.lineItems.single.quantity, 3);
      expect(returnedQuotation!.charges.deliveryCharges, 100);
      expect(returnedQuotation!.customerNotes, 'Latest customer notes');
      expect(returnedQuotation!.internalNotes, 'Latest internal notes');
    },
  );

  testWidgets('Previous Quotations Preview Edit opens Create in edit mode', (
    tester,
  ) async {
    final quotation = _quotation();
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

Quotation _quotation() {
  return Quotation(
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
}
