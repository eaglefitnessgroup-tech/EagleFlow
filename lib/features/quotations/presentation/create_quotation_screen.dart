import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../products/data/sample_products.dart';
import '../domain/quotation_defaults.dart';
import '../domain/quotation_line_item.dart';
import '../application/quotation_calculator.dart';
import 'widgets/create/quotation_page_header.dart';
import 'widgets/create/customer_information_card.dart';
import 'widgets/create/quotation_information_card.dart';
import 'widgets/create/selected_products_section.dart';
import 'widgets/create/additional_charges_card.dart';
import 'widgets/create/quotation_summary_card.dart';
import 'widgets/create/quotation_notes_card.dart';
import 'widgets/create/quotation_status_strip.dart';
import 'widgets/create/quotation_bottom_action_bar.dart';

class CreateQuotationScreen extends StatelessWidget {
  const CreateQuotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Mock Data Setup (from defaults and existing product list)
    final draft = QuotationDefaults.createEmptyDraft();
    final mockLineItems = sampleProducts.map((p) {
      return QuotationLineItem(
        id: 'li_${p.id}',
        productId: p.id,
        productCode: p.productCode,
        name: p.name,
        brand: p.brand,
        unitPrice: p.sellingPrice,
        quantity: 1,
        discount: 0.0,
        imagePath: p.imagePath,
      );
    }).toList();

    // 2. Calculations
    final subtotal = QuotationCalculator.calculateSubtotal(mockLineItems);
    final vat = QuotationCalculator.calculateVAT(subtotal, draft.charges);
    final grandTotal = QuotationCalculator.calculateGrandTotal(
      subtotal,
      draft.charges,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const QuotationStatusStrip(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth >= 1024;

                  if (isDesktop) {
                    return _buildDesktopLayout(
                      context,
                      draft.quotationNumber,
                      draft.salespersonId,
                      draft.createdDate,
                      draft.validUntil,
                      draft.expectedDelivery,
                      mockLineItems,
                      subtotal,
                      vat,
                      grandTotal,
                    );
                  }

                  return _buildMobileTabletLayout(
                    context,
                    draft.quotationNumber,
                    draft.salespersonId,
                    draft.createdDate,
                    draft.validUntil,
                    draft.expectedDelivery,
                    mockLineItems,
                    subtotal,
                    vat,
                    grandTotal,
                  );
                },
              ),
            ),
            const QuotationBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    String quotationNumber,
    String salespersonId,
    DateTime createdDate,
    DateTime validUntil,
    DateTime expectedDelivery,
    List<QuotationLineItem> items,
    double subtotal,
    double vat,
    double grandTotal,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuotationPageHeader(quotationNumber: quotationNumber),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const CustomerInformationCard(),
                    const SizedBox(height: 20),
                    QuotationInformationCard(
                      quotationNumber: quotationNumber,
                      salesperson: salespersonId,
                      date: createdDate,
                      validUntil: validUntil,
                      expectedDelivery: expectedDelivery,
                    ),
                    const SizedBox(height: 20),
                    SelectedProductsSection(items: items),
                    const SizedBox(height: 20),
                    const QuotationNotesCard(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    const AdditionalChargesCard(),
                    const SizedBox(height: 20),
                    QuotationSummaryCard(
                      totalQuantity: items.fold(
                        0,
                        (sum, i) => sum + i.quantity,
                      ),
                      subtotal: subtotal,
                      overallDiscount: 0.0,
                      vat: vat,
                      grandTotal: grandTotal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabletLayout(
    BuildContext context,
    String quotationNumber,
    String salespersonId,
    DateTime createdDate,
    DateTime validUntil,
    DateTime expectedDelivery,
    List<QuotationLineItem> items,
    double subtotal,
    double vat,
    double grandTotal,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuotationPageHeader(quotationNumber: quotationNumber),
          const SizedBox(height: 20),
          const CustomerInformationCard(),
          const SizedBox(height: 20),
          QuotationInformationCard(
            quotationNumber: quotationNumber,
            salesperson: salespersonId,
            date: createdDate,
            validUntil: validUntil,
            expectedDelivery: expectedDelivery,
          ),
          const SizedBox(height: 20),
          SelectedProductsSection(items: items),
          const SizedBox(height: 20),
          const AdditionalChargesCard(),
          const SizedBox(height: 20),
          QuotationSummaryCard(
            totalQuantity: items.fold(0, (sum, i) => sum + i.quantity),
            subtotal: subtotal,
            overallDiscount: 0.0,
            vat: vat,
            grandTotal: grandTotal,
          ),
          const SizedBox(height: 20),
          const QuotationNotesCard(),
        ],
      ),
    );
  }
}
