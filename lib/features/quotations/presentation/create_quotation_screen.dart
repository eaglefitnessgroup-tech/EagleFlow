import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../domain/quotation_defaults.dart';

import '../application/quotation_calculator.dart';
import '../application/quotation_controller.dart';
import '../application/quotation_validator.dart';
import '../../../../core/di/service_locator.dart';
import '../domain/quotation.dart';
import '../../products/domain/product.dart';
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
  late QuotationController _controller;
  bool _isInit = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Quotation) {
        _controller = QuotationController(args);
      } else {
        // Inject current user into the new draft so salesperson fields are
        // populated from the authenticated session rather than hardcoded.
        final user = ServiceLocator().authController.currentUser;
        final draft = QuotationDefaults.createEmptyDraft(
          salespersonId: user?.id ?? '',
        );
        _controller = QuotationController(draft);
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQuantityChanged(String itemId, int qty) async {
    final item = _controller.quotation.lineItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null || item.isCustom || item.productId == null) {
      _controller.updateQuantity(itemId, qty);
      return;
    }

    final product = ServiceLocator().productMasterController.products.where(
      (p) => p.id == item.productId,
    ).firstOrNull;

    if (product == null) {
      _controller.updateQuantity(itemId, qty);
      return;
    }

    final stock = await ServiceLocator().stockController.getCurrentStock(product);

    if (qty <= stock) {
      _controller.updateQuantity(itemId, qty);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $stock unit(s) available for ${product.name}.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    int fallbackQty = item.quantity;
    if (fallbackQty > stock) fallbackQty = stock;
    if (fallbackQty < 1) fallbackQty = 1;
    
    _controller.updateQuantity(itemId, fallbackQty + 1);
    await Future.delayed(const Duration(milliseconds: 50));
    _controller.updateQuantity(itemId, fallbackQty);
  }

  Future<void> _handleProductsAdded(List<Product> products) async {
    for (final product in products) {
      final existingItemIndex = _controller.quotation.lineItems.indexWhere((i) => i.productId == product.id);
      final existingQty = existingItemIndex >= 0 ? _controller.quotation.lineItems[existingItemIndex].quantity : 0;
      final requestedQty = existingQty + 1;
      
      final stock = await ServiceLocator().stockController.getCurrentStock(product);
      
      if (requestedQty <= stock) {
        _controller.addProduct(product);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only $stock unit(s) available for ${product.name}.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    // Guard: must be authenticated to save a quotation.
    final user = ServiceLocator().authController.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in again to create a quotation.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    // Validate stock before saving
    final Map<String, int> cachedStock = {};
    for (final item in _controller.quotation.lineItems) {
      if (item.isCustom || item.productId == null) continue;
      
      final product = ServiceLocator().productMasterController.products.where(
        (p) => p.id == item.productId,
      ).firstOrNull;
      
      if (product == null) continue;
      
      final stock = cachedStock[product.id] ?? await ServiceLocator().stockController.getCurrentStock(product);
      cachedStock[product.id] = stock;
      
      if (item.quantity <= stock) {
        continue;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot save. Only $stock unit(s) available for ${product.name}.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    try {
      final repo = ServiceLocator().quotationRepository;
      final savedQuotation = await repo.saveQuotation(_controller.quotation);
      _controller.loadQuotation(savedQuotation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
                  isSaving: _isSaving,
                  onSaveDraft: _handleSave,
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
                      salespersonId: quotation.salespersonId,
                      date: quotation.createdDate,
                      validUntil: quotation.validUntil,
                      expectedDelivery: quotation.expectedDelivery,
                    ),
                    const SizedBox(height: 20),
                    SelectedProductsSection(
                      items: quotation.lineItems,
                      onQuantityChanged: _handleQuantityChanged,
                      onUnitPriceChanged: _controller.updateUnitPrice,
                      onDiscountChanged: _controller.updateLineDiscount,
                      onRemove: _controller.removeItem,
                      onProductsAdded: _handleProductsAdded,
                      onCustomItemAdded: _controller.addCustomItem,
                      onCustomItemUpdated: _controller.updateCustomItem,
                    ),
                    const SizedBox(height: 20),
                    QuotationNotesCard(
                      initialCustomerNotes: quotation.customerNotes,
                      initialInternalNotes: quotation.internalNotes,
                      onCustomerNotesChanged: (val) =>
                          _controller.updateNotes(customerNotes: val),
                      onInternalNotesChanged: (val) =>
                          _controller.updateNotes(internalNotes: val),
                    ),
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
            salespersonId: quotation.salespersonId,
            date: quotation.createdDate,
            validUntil: quotation.validUntil,
            expectedDelivery: quotation.expectedDelivery,
          ),
          const SizedBox(height: 20),
          SelectedProductsSection(
            items: quotation.lineItems,
            onQuantityChanged: _handleQuantityChanged,
            onUnitPriceChanged: _controller.updateUnitPrice,
            onDiscountChanged: _controller.updateLineDiscount,
            onRemove: _controller.removeItem,
            onProductsAdded: _handleProductsAdded,
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
          QuotationNotesCard(
            initialCustomerNotes: quotation.customerNotes,
            initialInternalNotes: quotation.internalNotes,
            onCustomerNotesChanged: (val) =>
                _controller.updateNotes(customerNotes: val),
            onInternalNotesChanged: (val) =>
                _controller.updateNotes(internalNotes: val),
          ),
        ],
      ),
    );
  }
}
