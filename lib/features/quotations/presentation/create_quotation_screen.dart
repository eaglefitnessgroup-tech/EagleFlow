import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../domain/quotation_defaults.dart';

import '../application/quotation_calculator.dart';
import '../application/quotation_controller.dart';
import '../application/quotation_validator.dart';
import 'widgets/create/quotation_page_header.dart';
import 'widgets/create/customer_information_card.dart';
import 'widgets/create/quotation_information_card.dart';
import 'widgets/create/selected_products_section.dart';
import 'widgets/create/additional_charges_card.dart';
import 'widgets/create/quotation_summary_card.dart';
import 'widgets/create/quotation_notes_card.dart';
import 'widgets/create/quotation_status_strip.dart';
import 'widgets/create/quotation_bottom_action_bar.dart';

class CreateQuotationScreen extends StatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  late final QuotationController _controller;

  @override
  void initState() {
    super.initState();
    final draft = QuotationDefaults.createEmptyDraft();
    _controller = QuotationController(draft);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const QuotationStatusStrip(),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth >= 1024;
                      final quotation = _controller.quotation;

                      final subtotal = QuotationCalculator.calculateSubtotal(
                        quotation.lineItems,
                      );
                      final vat = QuotationCalculator.calculateVAT(
                        subtotal,
                        quotation.charges,
                      );
                      final grandTotal =
                          QuotationCalculator.calculateGrandTotal(
                            subtotal,
                            quotation.charges,
                          );

                      if (isDesktop) {
                        return _buildDesktopLayout(
                          context,
                          subtotal,
                          vat,
                          grandTotal,
                        );
                      }

                      return _buildMobileTabletLayout(
                        context,
                        subtotal,
                        vat,
                        grandTotal,
                      );
                    },
                  );
                },
              ),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final canPreview = QuotationValidator.canPreview(
                  _controller.quotation,
                );
                return QuotationBottomActionBar(
                  canPreview: canPreview,
                  onPreview: () {
                    Navigator.pushNamed(
                      context,
                      '/quotation-preview',
                      arguments: _controller,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    double subtotal,
    double vat,
    double grandTotal,
  ) {
    final quotation = _controller.quotation;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuotationPageHeader(quotationNumber: quotation.quotationNumber),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    CustomerInformationCard(
                      initialName: quotation.customerInfo.name,
                      initialCompany: quotation.customerInfo.company,
                      initialPhone: quotation.customerInfo.phone,
                      initialEmail: quotation.customerInfo.email,
                      initialProjectLocation:
                          quotation.customerInfo.projectLocation,
                      onNameChanged: _controller.updateCustomerName,
                      onCompanyChanged: (val) =>
                          _controller.updateCustomerDetails(company: val),
                      onPhoneChanged: (val) =>
                          _controller.updateCustomerDetails(phone: val),
                      onEmailChanged: (val) =>
                          _controller.updateCustomerDetails(email: val),
                      onProjectLocationChanged: (val) => _controller
                          .updateCustomerDetails(projectLocation: val),
                    ),
                    const SizedBox(height: 20),
                    QuotationInformationCard(
                      quotationNumber: quotation.quotationNumber,
                      salesperson: quotation.salespersonId,
                      date: quotation.createdDate,
                      validUntil: quotation.validUntil,
                      expectedDelivery: quotation.expectedDelivery,
                    ),
                    const SizedBox(height: 20),
                    SelectedProductsSection(
                      items: quotation.lineItems,
                      onQuantityChanged: _controller.updateQuantity,
                      onUnitPriceChanged: _controller.updateUnitPrice,
                      onDiscountChanged: _controller.updateLineDiscount,
                      onRemove: _controller.removeItem,
                      onProductsAdded: _controller.addProducts,
                      onCustomItemAdded: _controller.addCustomItem,
                      onCustomItemUpdated: _controller.updateCustomItem,
                    ),
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
                    AdditionalChargesCard(
                      initialDelivery: quotation.charges.deliveryCharges,
                      initialInstallation:
                          quotation.charges.installationCharges,
                      initialOther: quotation.charges.otherCharges,
                      initialDiscount: quotation.charges.overallDiscount,
                      initialVat: quotation.charges.vatPercentage,
                      onUpdateCharges: _controller.updateCharges,
                    ),
                    const SizedBox(height: 20),
                    QuotationSummaryCard(
                      totalQuantity: quotation.lineItems.fold(
                        0,
                        (sum, i) => sum + i.quantity,
                      ),
                      subtotal: subtotal,
                      overallDiscount: quotation.charges.overallDiscount,
                      vat: vat,
                      vatPercent: quotation.charges.vatPercentage,
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
    double subtotal,
    double vat,
    double grandTotal,
  ) {
    final quotation = _controller.quotation;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuotationPageHeader(quotationNumber: quotation.quotationNumber),
          const SizedBox(height: 20),
          CustomerInformationCard(
            initialName: quotation.customerInfo.name,
            initialCompany: quotation.customerInfo.company,
            initialPhone: quotation.customerInfo.phone,
            initialEmail: quotation.customerInfo.email,
            initialProjectLocation: quotation.customerInfo.projectLocation,
            onNameChanged: _controller.updateCustomerName,
            onCompanyChanged: (val) =>
                _controller.updateCustomerDetails(company: val),
            onPhoneChanged: (val) =>
                _controller.updateCustomerDetails(phone: val),
            onEmailChanged: (val) =>
                _controller.updateCustomerDetails(email: val),
            onProjectLocationChanged: (val) =>
                _controller.updateCustomerDetails(projectLocation: val),
          ),
          const SizedBox(height: 20),
          QuotationInformationCard(
            quotationNumber: quotation.quotationNumber,
            salesperson: quotation.salespersonId,
            date: quotation.createdDate,
            validUntil: quotation.validUntil,
            expectedDelivery: quotation.expectedDelivery,
          ),
          const SizedBox(height: 20),
          SelectedProductsSection(
            items: quotation.lineItems,
            onQuantityChanged: _controller.updateQuantity,
            onUnitPriceChanged: _controller.updateUnitPrice,
            onDiscountChanged: _controller.updateLineDiscount,
            onRemove: _controller.removeItem,
            onProductsAdded: _controller.addProducts,
            onCustomItemAdded: _controller.addCustomItem,
            onCustomItemUpdated: _controller.updateCustomItem,
          ),
          const SizedBox(height: 20),
          AdditionalChargesCard(
            initialDelivery: quotation.charges.deliveryCharges,
            initialInstallation: quotation.charges.installationCharges,
            initialOther: quotation.charges.otherCharges,
            initialDiscount: quotation.charges.overallDiscount,
            initialVat: quotation.charges.vatPercentage,
            onUpdateCharges: _controller.updateCharges,
          ),
          const SizedBox(height: 20),
          QuotationSummaryCard(
            totalQuantity: quotation.lineItems.fold(
              0,
              (sum, i) => sum + i.quantity,
            ),
            subtotal: subtotal,
            overallDiscount: quotation.charges.overallDiscount,
            vat: vat,
            vatPercent: quotation.charges.vatPercentage,
            grandTotal: grandTotal,
          ),
          const SizedBox(height: 20),
          const QuotationNotesCard(),
        ],
      ),
    );
  }
}
