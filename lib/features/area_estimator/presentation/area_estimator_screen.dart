import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/eagle_bottom_nav.dart';

class AreaEstimatorScreen extends StatefulWidget {
  const AreaEstimatorScreen({super.key});

  @override
  State<AreaEstimatorScreen> createState() => _AreaEstimatorScreenState();
}

class _AreaEstimatorScreenState extends State<AreaEstimatorScreen> {
  static const _units = ['m', 'cm', 'ft', 'in'];

  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _matLengthController = TextEditingController();
  final _matWidthController = TextEditingController();

  String _areaUnit = _units.first;
  String _matUnit = _units.first;
  String? _areaSqmResult;
  String? _areaSqftResult;
  String? _requiredMatsResult;

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _matLengthController.dispose();
    _matWidthController.dispose();
    super.dispose();
  }

  double _toMeters(double value, String unit) {
    return switch (unit) {
      'cm' => value / 100,
      'ft' => value * 0.3048,
      'in' => value * 0.0254,
      _ => value,
    };
  }

  void _calculate() {
    final rawValues = [
      _lengthController.text.trim(),
      _widthController.text.trim(),
      _matLengthController.text.trim(),
      _matWidthController.text.trim(),
    ];

    if (rawValues.any((value) => value.isEmpty)) {
      _showValidationMessage('Please complete all fields.');
      return;
    }

    final values = rawValues.map(double.tryParse).toList();
    if (values.any((value) => value == null || !value.isFinite)) {
      _showValidationMessage('Please enter valid numbers.');
      return;
    }

    final numericValues = values.cast<double>();
    if (numericValues.any((value) => value <= 0)) {
      _showValidationMessage('Values must be greater than zero.');
      return;
    }

    final length = _toMeters(numericValues[0], _areaUnit);
    final width = _toMeters(numericValues[1], _areaUnit);
    final matLength = _toMeters(numericValues[2], _matUnit);
    final matWidth = _toMeters(numericValues[3], _matUnit);

    final areaSqm = length * width;
    final areaSqft = areaSqm * 10.7639;
    final matAreaSqm = matLength * matWidth;

    if (!areaSqm.isFinite ||
        !areaSqft.isFinite ||
        !matAreaSqm.isFinite ||
        matAreaSqm <= 0) {
      _showValidationMessage('Please enter valid numbers.');
      return;
    }

    final matRatio = areaSqm / matAreaSqm;
    if (!matRatio.isFinite) {
      _showValidationMessage('Please enter valid numbers.');
      return;
    }

    final nearestWholeMat = matRatio.roundToDouble();
    final requiredMats = (matRatio - nearestWholeMat).abs() < 1e-10
        ? nearestWholeMat.toInt()
        : matRatio.ceil();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _areaSqmResult = areaSqm.toStringAsFixed(2);
      _areaSqftResult = areaSqft.toStringAsFixed(2);
      _requiredMatsResult = requiredMats.toString();
    });
  }

  void _showValidationMessage(String message) {
    setState(() {
      _areaSqmResult = null;
      _areaSqftResult = null;
      _requiredMatsResult = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final showBottomNavigation = MediaQuery.sizeOf(context).width < 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Area Estimator')),
      bottomNavigationBar: showBottomNavigation
          ? const EagleBottomNav(currentIndex: 3)
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection(
                      title: 'Area Dimensions',
                      child: _buildInputRow(
                        isMobile: isMobile,
                        lengthLabel: 'Length',
                        widthLabel: 'Width',
                        lengthController: _lengthController,
                        widthController: _widthController,
                        unitLabel: 'Unit',
                        unitValue: _areaUnit,
                        unitKey: const Key('area-unit-dropdown'),
                        onUnitChanged: (value) {
                          if (value != null) {
                            setState(() => _areaUnit = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Mat Dimensions',
                      child: _buildInputRow(
                        isMobile: isMobile,
                        lengthLabel: 'Mat Length',
                        widthLabel: 'Mat Width',
                        lengthController: _matLengthController,
                        widthController: _matWidthController,
                        unitLabel: 'Mat Unit',
                        unitValue: _matUnit,
                        unitKey: const Key('mat-unit-dropdown'),
                        onUnitChanged: (value) {
                          if (value != null) {
                            setState(() => _matUnit = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: isMobile
                          ? Alignment.center
                          : Alignment.centerRight,
                      child: SizedBox(
                        width: isMobile ? double.infinity : 180,
                        child: ElevatedButton(
                          key: const Key('calculate-button'),
                          onPressed: _calculate,
                          child: const Text('Calculate'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildResultSection(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required bool isMobile,
    required String lengthLabel,
    required String widthLabel,
    required TextEditingController lengthController,
    required TextEditingController widthController,
    required String unitLabel,
    required String unitValue,
    required Key unitKey,
    required ValueChanged<String?> onUnitChanged,
  }) {
    final fields = [
      TextFormField(
        key: Key('${lengthLabel.toLowerCase().replaceAll(' ', '-')}-field'),
        controller: lengthController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: lengthLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      TextFormField(
        key: Key('${widthLabel.toLowerCase().replaceAll(' ', '-')}-field'),
        controller: widthController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widthLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      DropdownButtonFormField<String>(
        key: unitKey,
        initialValue: unitValue,
        decoration: InputDecoration(
          labelText: unitLabel,
          border: const OutlineInputBorder(),
        ),
        items: _units
            .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: onUnitChanged,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            fields[i],
            if (i < fields.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          Expanded(child: fields[i]),
          if (i < fields.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _buildResultSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _ResultRow(
            label: 'Area (SQM)',
            value: _areaSqmResult,
            valueKey: const Key('area-sqm-result'),
          ),
          const Divider(height: 24, color: AppColors.border),
          _ResultRow(
            label: 'Area (SQFT)',
            value: _areaSqftResult,
            valueKey: const Key('area-sqft-result'),
          ),
          const Divider(height: 24, color: AppColors.border),
          _ResultRow(
            label: 'Required Mats',
            value: _requiredMatsResult,
            valueKey: const Key('required-mats-result'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String? value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value ?? '—',
          key: valueKey,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
