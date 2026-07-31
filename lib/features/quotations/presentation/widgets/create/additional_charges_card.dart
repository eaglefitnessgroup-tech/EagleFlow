import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class AdditionalChargesCard extends StatefulWidget {
  final double initialDelivery;
  final double initialInstallation;
  final double initialOther;
  final double initialDiscount;
  final double initialVat;
  final void Function({
    double? delivery,
    double? installation,
    double? other,
    double? discount,
    double? vat,
  })
  onUpdateCharges;

  const AdditionalChargesCard({
    super.key,
    required this.initialDelivery,
    required this.initialInstallation,
    required this.initialOther,
    required this.initialDiscount,
    required this.initialVat,
    required this.onUpdateCharges,
  });

  @override
  State<AdditionalChargesCard> createState() => _AdditionalChargesCardState();
}

class _AdditionalChargesCardState extends State<AdditionalChargesCard> {
  late final TextEditingController _deliveryCtrl;
  late final TextEditingController _installationCtrl;
  late final TextEditingController _otherCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _vatCtrl;

  final FocusNode _deliveryFocus = FocusNode();
  final FocusNode _installationFocus = FocusNode();
  final FocusNode _otherFocus = FocusNode();
  final FocusNode _discountFocus = FocusNode();
  final FocusNode _vatFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _deliveryCtrl = TextEditingController(
      text: _format(widget.initialDelivery),
    );
    _installationCtrl = TextEditingController(
      text: _format(widget.initialInstallation),
    );
    _otherCtrl = TextEditingController(text: _format(widget.initialOther));
    _discountCtrl = TextEditingController(
      text: _format(widget.initialDiscount),
    );
    _vatCtrl = TextEditingController(text: _format(widget.initialVat));

    _deliveryFocus.addListener(_onDeliveryFocus);
    _installationFocus.addListener(_onInstallationFocus);
    _otherFocus.addListener(_onOtherFocus);
    _discountFocus.addListener(_onDiscountFocus);
    _vatFocus.addListener(_onVatFocus);
  }

  @override
  void didUpdateWidget(AdditionalChargesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_deliveryFocus.hasFocus &&
        oldWidget.initialDelivery != widget.initialDelivery) {
      _deliveryCtrl.text = _format(widget.initialDelivery);
    }
    if (!_installationFocus.hasFocus &&
        oldWidget.initialInstallation != widget.initialInstallation) {
      _installationCtrl.text = _format(widget.initialInstallation);
    }
    if (!_otherFocus.hasFocus &&
        oldWidget.initialOther != widget.initialOther) {
      _otherCtrl.text = _format(widget.initialOther);
    }
    if (!_discountFocus.hasFocus &&
        oldWidget.initialDiscount != widget.initialDiscount) {
      _discountCtrl.text = _format(widget.initialDiscount);
    }
    if (!_vatFocus.hasFocus && oldWidget.initialVat != widget.initialVat) {
      _vatCtrl.text = _format(widget.initialVat);
    }
  }

  @override
  void dispose() {
    _deliveryFocus.removeListener(_onDeliveryFocus);
    _installationFocus.removeListener(_onInstallationFocus);
    _otherFocus.removeListener(_onOtherFocus);
    _discountFocus.removeListener(_onDiscountFocus);
    _vatFocus.removeListener(_onVatFocus);

    _deliveryFocus.dispose();
    _installationFocus.dispose();
    _otherFocus.dispose();
    _discountFocus.dispose();
    _vatFocus.dispose();

    _deliveryCtrl.dispose();
    _installationCtrl.dispose();
    _otherCtrl.dispose();
    _discountCtrl.dispose();
    _vatCtrl.dispose();
    super.dispose();
  }

  String _format(double val) => val.toStringAsFixed(2);

  void _onDeliveryFocus() {
    if (!_deliveryFocus.hasFocus) {
      final val = double.tryParse(_deliveryCtrl.text) ?? 0.0;
      final clamped = val < 0 ? 0.0 : val;
      _deliveryCtrl.text = _format(clamped);
      widget.onUpdateCharges(delivery: clamped);
    }
  }

  void _onInstallationFocus() {
    if (!_installationFocus.hasFocus) {
      final val = double.tryParse(_installationCtrl.text) ?? 0.0;
      final clamped = val < 0 ? 0.0 : val;
      _installationCtrl.text = _format(clamped);
      widget.onUpdateCharges(installation: clamped);
    }
  }

  void _onOtherFocus() {
    if (!_otherFocus.hasFocus) {
      final val = double.tryParse(_otherCtrl.text) ?? 0.0;
      final clamped = val < 0 ? 0.0 : val;
      _otherCtrl.text = _format(clamped);
      widget.onUpdateCharges(other: clamped);
    }
  }

  void _onDiscountFocus() {
    if (!_discountFocus.hasFocus) {
      final val = double.tryParse(_discountCtrl.text) ?? 0.0;
      final clamped = val < 0 ? 0.0 : val;
      _discountCtrl.text = _format(clamped);
      widget.onUpdateCharges(discount: clamped);
    }
  }

  void _onVatFocus() {
    if (!_vatFocus.hasFocus) {
      final val = double.tryParse(_vatCtrl.text) ?? 0.0;
      final clamped = val < 0 ? 0.0 : val;
      _vatCtrl.text = _format(clamped);
      widget.onUpdateCharges(vat: clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return _buildCard(
          isMobile,
          title: isMobile ? 'Charges' : 'Additional Charges & Discount',
          child: Column(
            children: [
              if (isMobile) ...[
                _buildNumberField('Delivery', _deliveryCtrl, _deliveryFocus),
                const SizedBox(height: 16),
                _buildNumberField(
                  'Installation',
                  _installationCtrl,
                  _installationFocus,
                ),
                const SizedBox(height: 16),
                _buildNumberField('Other Charges', _otherCtrl, _otherFocus),
                const SizedBox(height: 16),
                _buildNumberField('Discount', _discountCtrl, _discountFocus),
                const SizedBox(height: 16),
                _buildNumberField('VAT %', _vatCtrl, _vatFocus),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        'Delivery',
                        _deliveryCtrl,
                        _deliveryFocus,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        'Installation',
                        _installationCtrl,
                        _installationFocus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        'Other Charges',
                        _otherCtrl,
                        _otherFocus,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        'Discount',
                        _discountCtrl,
                        _discountFocus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNumberField('VAT %', _vatCtrl, _vatFocus),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    bool isMobile, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryBlue),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
