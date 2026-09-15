import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes/app_routes.dart';
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

    _controller.updateQuantity(itemId, qty);
  }

  void _handleProductsAdded(List<Product> products) {
    for (final product in products) {
      _controller.addProduct(product);
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebar(context),
            Expanded(
              child: Column(
                children: [
                  const QuotationStatusStrip(),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) {
                        final quotation = _controller.quotation;
                        final subtotal = QuotationCalculator.calculateSubtotal(
                          quotation.lineItems,
                        );
                        final vat = QuotationCalculator.calculateVAT(
                          subtotal,
                          quotation.charges,
                        );
                        final grandTotal = QuotationCalculator.calculateGrandTotal(
                          subtotal,
                          quotation.charges,
                        );

                        return _buildDesktopLayout(
                          context,
                          subtotal,
                          vat,
                          grandTotal,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rocket_launch, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'EagleFlow',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSidebarItem(
            context,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: AppRoutes.dashboard,
            isSelected: false,
          ),
          _buildSidebarItem(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            route: AppRoutes.products,
            isSelected: false,
          ),
          _buildSidebarItem(
            context,
            icon: Icons.history_outlined,
            label: 'Quotations',
            route: AppRoutes.previousQuotations,
            isSelected: true,
          ),
          if (ServiceLocator().authController.canManageStock)
            _buildSidebarItem(
              context,
              icon: Icons.admin_panel_settings_outlined,
              label: 'Stock Management',
              route: AppRoutes.stockManagement,
              isSelected: false,
            ),
          const Spacer(),
          _buildSidebarItem(
            context,
            icon: Icons.person_outline,
            label: 'Profile',
            route: AppRoutes.profile,
            isSelected: false,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? route,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: route != null && !isSelected ? () => Navigator.of(context).pushNamed(route) : null,
        hoverColor: AppColors.primarySoft.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                width: 4,
              ),
            ),
            color: isSelected ? AppColors.primarySoft.withValues(alpha: 0.3) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryBlue : AppColors.mutedText, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryBlue : AppColors.mutedText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 120),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuotationPageHeader(quotationNumber: quotation.quotationNumber),
              const SizedBox(height: 16),
              // Compact Customer and Quotation Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: CustomerInformationCard(
                      initialName: quotation.customerInfo.name,
                      initialCompany: quotation.customerInfo.company,
                      initialPhone: quotation.customerInfo.phone,
                      initialEmail: quotation.customerInfo.email,
                      initialProjectLocation: quotation.customerInfo.projectLocation,
                      onNameChanged: _controller.updateCustomerName,
                      onCompanyChanged: (val) => _controller.updateCustomerDetails(company: val),
                      onPhoneChanged: (val) => _controller.updateCustomerDetails(phone: val),
                      onEmailChanged: (val) => _controller.updateCustomerDetails(email: val),
                      onProjectLocationChanged: (val) => _controller.updateCustomerDetails(projectLocation: val),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: QuotationInformationCard(
                      quotationNumber: quotation.quotationNumber,
                      salespersonId: quotation.salespersonId,
                      date: quotation.createdDate,
                      validUntil: quotation.validUntil,
                      expectedDelivery: quotation.expectedDelivery,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: QuotationNotesCard(
                      initialCustomerNotes: quotation.customerNotes,
                      initialInternalNotes: quotation.internalNotes,
                      onCustomerNotesChanged: (val) => _controller.updateNotes(customerNotes: val),
                      onInternalNotesChanged: (val) => _controller.updateNotes(internalNotes: val),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        AdditionalChargesCard(
                          initialDelivery: quotation.charges.deliveryCharges,
                          initialInstallation: quotation.charges.installationCharges,
                          initialOther: quotation.charges.otherCharges,
                          initialDiscount: quotation.charges.overallDiscount,
                          initialVat: quotation.charges.vatPercentage,
                          onUpdateCharges: _controller.updateCharges,
                        ),
                        const SizedBox(height: 24),
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
        ),
      ),
    );
  }
}
