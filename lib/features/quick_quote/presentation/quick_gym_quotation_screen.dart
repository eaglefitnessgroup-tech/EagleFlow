import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../application/quick_quote_controller.dart';
import '../application/quick_quote_draft_factory.dart';
import '../domain/quick_quote_product_mapping.dart';
import '../domain/quick_quote_result.dart';
import '../domain/quick_quote_rules.dart';
import '../domain/quick_quote_selection.dart';

class QuickGymQuotationScreen extends StatefulWidget {
  const QuickGymQuotationScreen({
    required this.controller,
    this.initializeOnMount = true,
    super.key,
  });

  final QuickQuoteController controller;
  final bool initializeOnMount;

  @override
  State<QuickGymQuotationScreen> createState() =>
      _QuickGymQuotationScreenState();
}

class _QuickGymQuotationScreenState extends State<QuickGymQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();

  QuickQuoteController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    if (widget.initializeOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.initialize();
      });
    }
  }

  @override
  void didUpdateWidget(covariant QuickGymQuotationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _budgetController.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quick Gym Quotation')),
      body: switch (_controller.status) {
        QuickQuoteControllerStatus.loading => const Center(
          key: Key('quick-quote-loading'),
          child: CircularProgressIndicator(),
        ),
        QuickQuoteControllerStatus.error => _fatalError(),
        _ => _content(),
      },
    );
  }

  Widget _fatalError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.mutedText,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              _controller.errorMessage ?? 'Quick Quote is unavailable.',
              key: const Key('quick-quote-fatal-error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const Key('quick-quote-retry'),
              onPressed: _controller.initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _content() => LayoutBuilder(
    builder: (context, constraints) {
      final mobile = constraints.maxWidth < 760;
      return SingleChildScrollView(
        key: const Key('quick-quote-scroll'),
        padding: EdgeInsets.fromLTRB(
          mobile ? 16 : 32,
          20,
          mobile ? 16 : 32,
          40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_controller.mappingNotice != null) ...[
                    _MessageBand(
                      key: const Key('mapping-cache-notice'),
                      icon: Icons.info_outline,
                      message: _controller.mappingNotice!,
                      background: AppColors.statusPendingBg,
                      foreground: AppColors.statusPendingText,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_controller.configurationNotice != null) ...[
                    _MessageBand(
                      key: const Key('configuration-cache-notice'),
                      icon: Icons.info_outline,
                      message: _controller.configurationNotice!,
                      background: AppColors.statusPendingBg,
                      foreground: AppColors.statusPendingText,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (mobile)
                    Column(
                      children: [
                        _setup(),
                        const SizedBox(height: 16),
                        _cardio(),
                      ],
                    )
                  else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _setup()),
                          const SizedBox(width: 16),
                          Expanded(child: _cardio()),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  _availability(mobile),
                  if (_controller.generationError != null) ...[
                    const SizedBox(height: 16),
                    _MessageBand(
                      key: const Key('generation-error'),
                      icon: Icons.error_outline,
                      message: _controller.generationError!,
                      background: AppColors.statusRejectedBg,
                      foreground: AppColors.statusRejectedText,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      key: const Key('generate-gym-button-box'),
                      width: mobile ? double.infinity : 240,
                      child: ElevatedButton.icon(
                        key: const Key('generate-gym-button'),
                        onPressed: _controller.isGenerating ? null : _generate,
                        icon: _controller.isGenerating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(
                          _controller.isGenerating
                              ? 'Generating…'
                              : 'Generate Gym',
                        ),
                      ),
                    ),
                  ),
                  if (_controller.result case final result?) ...[
                    const SizedBox(height: 24),
                    for (
                      var index = 0;
                      index < result.warnings.length;
                      index++
                    ) ...[
                      _MessageBand(
                        key: Key('quick-quote-review-warning-$index'),
                        icon: Icons.warning_amber_rounded,
                        message: result.warnings[index].message,
                        background: AppColors.statusPendingBg,
                        foreground: AppColors.statusPendingText,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _resultSummary(result, mobile),
                    const SizedBox(height: 16),
                    _equipment(result.selections, mobile),
                    if (QuickQuoteDraftFactory.canCreateDraft(result)) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: mobile ? double.infinity : 240,
                          child: ElevatedButton.icon(
                            key: const Key('continue-to-quotation-button'),
                            onPressed: () => _continueToQuotation(result),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Continue to Quotation'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _setup() {
    final brand = _controller.strengthBrand;
    return _Section(
      title: 'Budget & Strength',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('target-budget-field'),
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            validator: _controller.validateBudget,
            decoration: InputDecoration(
              labelText: 'Target Equipment Budget',
              prefixText: 'AED  ',
              border: const OutlineInputBorder(),
              errorText: _controller.budgetError,
              helperText:
                  'Target total includes VAT.\nDelivery, installation and other later quotation charges are not included.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: const Key('strength-brand-selector'),
            initialValue: brand,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Strength Brand',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in _controller.strengthBrands)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: (value) {
              if (value != null) _controller.selectStrengthBrand(value);
            },
          ),
          if (brand != null && isPremierBrand(brand)) ...[
            const SizedBox(height: 20),
            _SeriesSelector(
              title: 'Pin Loaded Series',
              keyPrefix: 'premier-pin',
              selectedValue: _controller.premierPinSeriesPrefix,
              options: const [
                ('APN', 'Active Series (Pin) / APN'),
                ('PXN', 'Torque Series (Pin) / PXN'),
                ('EPN', 'Elite Series (Pin) / EPN'),
              ],
              onSelected: _controller.selectPremierPinSeries,
            ),
            const SizedBox(height: 18),
            _SeriesSelector(
              title: 'Plate Loaded Series',
              keyPrefix: 'premier-plate',
              selectedValue: _controller.premierPlateSeriesPrefix,
              options: const [
                ('APL', 'Active Series (PL) / APL'),
                ('PXL', 'Torque Series (PL) / PXL'),
              ],
              onSelected: _controller.selectPremierPlateSeries,
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardio() => _Section(
    title: 'Cardio Equipment',
    subtitle: 'Select one eligible product for each role.',
    child: Column(
      children: [
        for (
          var index = 0;
          index < QuickQuoteCardioRole.values.length;
          index++
        ) ...[
          _cardioSelector(QuickQuoteCardioRole.values[index]),
          if (index < QuickQuoteCardioRole.values.length - 1)
            const SizedBox(height: 14),
        ],
      ],
    ),
  );

  Widget _cardioSelector(QuickQuoteCardioRole role) {
    final candidates = _controller.cardioCandidates(role);
    return DropdownButtonFormField<String>(
      key: Key('cardio-${role.name}-selector'),
      initialValue: _controller.selectedCardioProductId(role),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _cardioLabel(role),
        border: const OutlineInputBorder(),
        helperText: candidates.isEmpty
            ? 'No mapped active eligible candidates.'
            : null,
        helperStyle: const TextStyle(color: AppColors.statusRejectedText),
      ),
      items: [
        for (final product in candidates)
          DropdownMenuItem(
            value: product.id,
            child: Text(
              '${product.name} · ${product.brand} · ${_money(product.sellingPrice)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: candidates.isEmpty
          ? null
          : (value) => _controller.selectCardioProduct(role, value),
    );
  }

  Widget _availability(bool mobile) {
    final matrix = _Section(
      title: 'Strength Availability',
      subtitle:
          'A missing counterpart does not block an otherwise covered area.',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          const TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            children: [
              _TableHeader('Area'),
              _TableHeader('Pin'),
              _TableHeader('Plate'),
            ],
          ),
          for (final area in QuickQuoteStrengthArea.values)
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              children: [
                _AvailabilityLabel(
                  _strengthAreaLabel(area),
                  key: Key('availability-${area.name}'),
                ),
                _AvailabilityMark(
                  available: _controller.hasStrengthCandidate(
                    area,
                    QuickQuoteLoadType.pinLoaded,
                  ),
                ),
                _AvailabilityMark(
                  available: _controller.hasStrengthCandidate(
                    area,
                    QuickQuoteLoadType.plateLoaded,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    final additional = _Section(
      title: 'Additional Availability',
      child: Column(
        children: [
          _AvailabilityRow(
            label: 'Smith',
            available: _controller.hasMultifunctionCandidate(
              QuickQuoteMultifunctionRole.smithMachine,
            ),
          ),
          _AvailabilityRow(
            label: 'Functional Trainer',
            available: _controller.hasMultifunctionCandidate(
              QuickQuoteMultifunctionRole.functionalTrainer,
            ),
          ),
          _AvailabilityRow(
            label: 'Multi Station',
            available: _controller.hasMultifunctionCandidate(
              QuickQuoteMultifunctionRole.multiStation,
            ),
          ),
          _AvailabilityRow(
            label: 'Dumbbell full-set bundle',
            available: _controller.hasDumbbellFullSetBundle,
          ),
          _AvailabilityRow(
            label: 'Weight plate complete family',
            available: _controller.hasCompleteWeightPlateFamily,
            showDivider: false,
          ),
        ],
      ),
    );
    if (mobile) {
      return Column(children: [matrix, const SizedBox(height: 16), additional]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: matrix),
          const SizedBox(width: 16),
          Expanded(child: additional),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _controller.generate(_budgetController.text);
  }

  void _continueToQuotation(QuickQuoteResult result) {
    if (!QuickQuoteDraftFactory.canCreateDraft(result)) return;
    final draft = QuickQuoteDraftFactory.create(
      result: result,
      salespersonId: ServiceLocator().authController.currentUser?.id ?? '',
    );
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.createQuotation, arguments: draft);
  }

  Widget _resultSummary(QuickQuoteResult result, bool mobile) {
    final covered = result.strengthCoverage.values
        .where((value) => value.hasCoverage)
        .length;
    final pin = result.strengthCoverage.values
        .where((value) => value.pinCount > 0)
        .length;
    final plate = result.strengthCoverage.values
        .where((value) => value.plateCount > 0)
        .length;
    final multifunction = result.selectedMultifunctionRoles
        .map(_multifunctionLabel)
        .join(', ');
    final dumbbell = result.dumbbellConfiguration;
    final plates = result.plateConfiguration;
    final cardioCount = result.selections
        .where((selection) => selection.kind == QuickQuoteSelectionKind.cardio)
        .length;
    final totals = Column(
      children: [
        _SummaryRow(label: 'Target Budget', value: _money(result.targetBudget)),
        _SummaryRow(
          label: 'Equipment Subtotal',
          value: _money(result.subtotal),
        ),
        _SummaryRow(label: 'VAT', value: _money(result.vat)),
        _SummaryRow(
          label: 'Final Total',
          value: _money(result.grandTotal),
          emphasized: true,
        ),
        _SummaryRow(
          label: result.signedDifference > 0 ? 'Over Target' : 'Remaining',
          value: _money(result.absoluteDifference),
        ),
        if (result.status == QuickQuoteBudgetStatus.insufficientBudget) ...[
          const Divider(height: 24, color: AppColors.border),
          _SummaryRow(
            label: 'Minimum Balanced Total',
            value: _money(result.minimumBalancedGrandTotal),
          ),
          _SummaryRow(
            label: 'Shortfall',
            value: _money(result.minimumBalancedShortfall),
          ),
        ],
        const SizedBox(height: 12),
        QuickQuoteBudgetStatusBanner(status: result.status),
      ],
    );
    final coverage = Column(
      children: [
        _SummaryRow(
          label: 'Total selected line count',
          value: '${result.selections.length}',
        ),
        _SummaryRow(
          label: 'Cardio coverage',
          value: '$cardioCount configured role${cardioCount == 1 ? '' : 's'}',
        ),
        _SummaryRow(label: 'Strength area coverage', value: '$covered/7 areas'),
        _SummaryRow(
          label: 'Pin/Plate coverage',
          value: 'Pin: $pin areas · Plate: $plate areas',
        ),
        _SummaryRow(
          label: 'Multifunction selections',
          value: multifunction.isEmpty ? 'None' : multifunction,
        ),
        _SummaryRow(
          label: 'Dumbbell configuration',
          value: dumbbell.familyKey == null
              ? 'None'
              : '${dumbbell.familyKey} · Full: ${dumbbell.hasFullSet ? 'Yes' : 'No'} · Half: ${dumbbell.hasHalfSet ? 'Yes' : 'No'} · Racks: ${dumbbell.rackQuantity}',
        ),
        _SummaryRow(
          label: 'Plate family + tier',
          value: plates.familyKey == null
              ? 'None'
              : '${plates.familyKey} · ${plates.quantityEach} each',
        ),
      ],
    );
    return _Section(
      key: const Key('quick-quote-result-summary'),
      title: 'Result Summary',
      child: mobile
          ? Column(
              children: [
                totals,
                const Divider(height: 32, color: AppColors.border),
                coverage,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: totals),
                const SizedBox(width: 28),
                const SizedBox(
                  height: 260,
                  child: VerticalDivider(color: AppColors.border),
                ),
                const SizedBox(width: 28),
                Expanded(child: coverage),
              ],
            ),
    );
  }

  Widget _equipment(List<QuickQuoteSelection> selections, bool mobile) =>
      _Section(
        key: const Key('selected-equipment-preview'),
        title: 'Selected Equipment',
        subtitle: 'Read-only preview in configured order.',
        child: mobile
            ? Column(
                children: [
                  for (var index = 0; index < selections.length; index++) ...[
                    _MobileEquipmentRow(
                      key: Key('selected-equipment-row-$index'),
                      selection: selections[index],
                    ),
                    if (index < selections.length - 1)
                      const Divider(height: 24, color: AppColors.border),
                  ],
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.background,
                      ),
                      columns: const [
                        DataColumn(label: Text('Product Name')),
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Brand')),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Unit Price'), numeric: true),
                        DataColumn(label: Text('Line Total'), numeric: true),
                      ],
                      rows: [
                        for (var index = 0; index < selections.length; index++)
                          DataRow(
                            key: ValueKey('selected-equipment-row-$index'),
                            cells: [
                              DataCell(
                                Text(selections[index].candidate.product.name),
                              ),
                              DataCell(
                                Text(
                                  selections[index]
                                      .candidate
                                      .product
                                      .normalizedProductCode,
                                ),
                              ),
                              DataCell(
                                Text(selections[index].candidate.product.brand),
                              ),
                              DataCell(Text('${selections[index].quantity}')),
                              DataCell(
                                Text(
                                  _money(
                                    selections[index]
                                        .candidate
                                        .product
                                        .sellingPrice,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(_money(selections[index].lineSubtotal)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _SeriesSelector extends StatelessWidget {
  const _SeriesSelector({
    required this.title,
    required this.keyPrefix,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });
  final String title;
  final String keyPrefix;
  final String selectedValue;
  final List<(String, String)> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              key: Key('$keyPrefix-${option.$1}'),
              label: Text(option.$2),
              selected: selectedValue == option.$1,
              onSelected: (_) => onSelected(option.$1),
              showCheckmark: false,
              selectedColor: AppColors.primarySoft,
              side: BorderSide(
                color: selectedValue == option.$1
                    ? AppColors.primaryBlue
                    : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: selectedValue == option.$1
                    ? AppColors.primaryDark
                    : AppColors.charcoal,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    ],
  );
}

class _MessageBand extends StatelessWidget {
  const _MessageBand({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
    super.key,
  });
  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: foreground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      label,
      textAlign: label == 'Area' ? TextAlign.left : TextAlign.center,
      style: const TextStyle(
        color: AppColors.mutedText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(label),
  );
}

class _AvailabilityMark extends StatelessWidget {
  const _AvailabilityMark({required this.available});
  final bool available;
  @override
  Widget build(BuildContext context) => Semantics(
    label: available ? 'Available' : 'Unavailable',
    child: Icon(
      available ? Icons.check_circle : Icons.remove_circle_outline,
      size: 20,
      color: available ? AppColors.statusApprovedText : AppColors.mutedText,
    ),
  );
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({
    required this.label,
    required this.available,
    this.showDivider = true,
  });
  final String label;
  final bool available;
  final bool showDivider;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            _AvailabilityMark(available: available),
            const SizedBox(width: 6),
            Text(
              available ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: available
                    ? AppColors.statusApprovedText
                    : AppColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(height: 1, color: AppColors.border),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized ? AppColors.charcoal : AppColors.mutedText,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.charcoal,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MobileEquipmentRow extends StatelessWidget {
  const _MobileEquipmentRow({required this.selection, super.key});
  final QuickQuoteSelection selection;
  @override
  Widget build(BuildContext context) {
    final product = selection.candidate.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(
          '${product.normalizedProductCode} · ${product.brand}',
          style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Qty ${selection.quantity}'),
            const Spacer(),
            Text(
              _money(selection.lineSubtotal),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_money(product.sellingPrice)} each',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class QuickQuoteBudgetStatusBanner extends StatelessWidget {
  const QuickQuoteBudgetStatusBanner({required this.status, super.key});

  final QuickQuoteBudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final presentation = _statusPresentation(status);
    return _MessageBand(
      key: const Key('quick-quote-result-status'),
      icon: presentation.icon,
      message: presentation.label,
      background: presentation.background,
      foreground: presentation.foreground,
    );
  }
}

({String label, IconData icon, Color background, Color foreground})
_statusPresentation(QuickQuoteBudgetStatus status) => switch (status) {
  QuickQuoteBudgetStatus.insufficientBudget => (
    label: 'Insufficient budget',
    icon: Icons.warning_amber_rounded,
    background: AppColors.statusRejectedBg,
    foreground: AppColors.statusRejectedText,
  ),
  QuickQuoteBudgetStatus.underTarget => (
    label: 'Under target',
    icon: Icons.check_circle_outline,
    background: AppColors.statusApprovedBg,
    foreground: AppColors.statusApprovedText,
  ),
  QuickQuoteBudgetStatus.exactTarget => (
    label: 'Exact',
    icon: Icons.check_circle_outline,
    background: AppColors.primarySoft,
    foreground: AppColors.primaryDark,
  ),
  QuickQuoteBudgetStatus.overTarget => (
    label: 'Over target',
    icon: Icons.info_outline,
    background: AppColors.statusPendingBg,
    foreground: AppColors.statusPendingText,
  ),
};

String _money(double value) =>
    'AED ${NumberFormat('#,##0.00', 'en').format(value)}';

String _cardioLabel(QuickQuoteCardioRole role) => switch (role) {
  QuickQuoteCardioRole.treadmill => 'Treadmill',
  QuickQuoteCardioRole.crossTrainer => 'Cross Trainer',
  QuickQuoteCardioRole.recumbentBike => 'Recumbent Bike',
  QuickQuoteCardioRole.uprightBike => 'Upright Bike',
  QuickQuoteCardioRole.spinningBike => 'Spinning Bike',
};

String _strengthAreaLabel(QuickQuoteStrengthArea area) => switch (area) {
  QuickQuoteStrengthArea.chest => 'Chest',
  QuickQuoteStrengthArea.back => 'Back',
  QuickQuoteStrengthArea.shoulder => 'Shoulder',
  QuickQuoteStrengthArea.legs => 'Legs',
  QuickQuoteStrengthArea.arms => 'Arms',
  QuickQuoteStrengthArea.glutes => 'Glutes',
  QuickQuoteStrengthArea.core => 'Core',
};

String _multifunctionLabel(QuickQuoteMultifunctionRole role) => switch (role) {
  QuickQuoteMultifunctionRole.smithMachine => 'Smith',
  QuickQuoteMultifunctionRole.functionalTrainer => 'Functional Trainer',
  QuickQuoteMultifunctionRole.multiStation => 'Multi Station',
};
