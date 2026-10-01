import '../../../../../../core/utils/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../application/quotation_calculator.dart';
import '../../../application/quotation_family.dart';
import '../../../domain/quotation.dart';

class QuotationListView extends StatelessWidget {
  final List<QuotationFamily> families;
  final Map<String, String> salespersonNames;
  final ValueChanged<Quotation> onView;
  final ValueChanged<Quotation> onEdit;
  final ValueChanged<Quotation> onRevise;
  final ValueChanged<Quotation> onDuplicate;
  final ValueChanged<Quotation> onShare;
  final ValueChanged<Quotation> onDelete;
  final VoidCallback onCreate;

  const QuotationListView({
    super.key,
    required this.families,
    this.salespersonNames = const {},
    required this.onView,
    required this.onEdit,
    required this.onRevise,
    required this.onDuplicate,
    required this.onShare,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    if (families.isEmpty) return _buildEmptyState(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          final rows = _rows;
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              return _buildMobileCard(context, row.family, row.quotation);
            },
          );
        }

        return _buildDesktopTable(context);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No quotations found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You haven\'t created any quotations yet, or none match your filters.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Create New Quotation',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(
    BuildContext context,
    QuotationFamily family,
    Quotation quotation,
  ) {
    final formatter = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('MMM dd, yyyy');
    final salesperson =
        salespersonNames[quotation.salespersonId] ??
        (quotation.salespersonId.isNotEmpty ? quotation.salespersonId : '');

    return Container(
      key: Key('quotation-card-${quotation.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    quotation.displayQuotationNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileRow('Customer', quotation.customerInfo.name),
                if (salesperson.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildMobileRow('Salesperson', salesperson),
                ],
                const SizedBox(height: 10),
                _buildMobileRow('Date', dateFmt.format(quotation.createdDate)),
                const SizedBox(height: 10),
                _buildMobileRow(
                  'Amount',
                  'AED ${formatter.format(QuotationCalculator.calculateGrandTotal(quotation.lineItems, quotation.charges))}',
                  isBold: true,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                TextButton.icon(
                  key: Key('quotation-view-${quotation.id}'),
                  onPressed: () => onView(quotation),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                ),
                if (family.canEdit(quotation))
                  TextButton.icon(
                    key: Key('quotation-edit-${quotation.id}'),
                    onPressed: () => onEdit(quotation),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                if (family.canRevise(quotation))
                  TextButton.icon(
                    key: Key('quotation-revise-${quotation.id}'),
                    onPressed: () => onRevise(quotation),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Revise'),
                  ),
                _buildActionMenu(context, family, quotation),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isBold ? AppColors.charcoal : AppColors.mutedText,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final formatter = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('MMM dd, yyyy');
    final compactActionStyle = TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    final rows = _rows;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          dataRowMinHeight: 56,
          dataRowMaxHeight: 56,
          horizontalMargin: 24,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('QT No.')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Salesperson')),
            DataColumn(label: Text('Amount'), numeric: true),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((row) {
            final quotation = row.quotation;
            final family = row.family;
            return DataRow(
              key: ValueKey('quotation-row-${quotation.id}'),
              onSelectChanged: (_) => onView(quotation),
              cells: [
                DataCell(
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          quotation.displayQuotationNumber,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(dateFmt.format(quotation.createdDate))),
                DataCell(Text(quotation.customerInfo.name)),
                DataCell(
                  Text(
                    salespersonNames[quotation.salespersonId] ??
                        (quotation.salespersonId.isNotEmpty
                            ? quotation.salespersonId
                            : '—'),
                  ),
                ),
                DataCell(
                  Text(
                    'AED ${formatter.format(QuotationCalculator.calculateGrandTotal(quotation.lineItems, quotation.charges))}',
                  ),
                ),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          key: Key('quotation-view-${quotation.id}'),
                          style: compactActionStyle,
                          onPressed: () => onView(quotation),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('View'),
                        ),
                        if (family.canEdit(quotation)) ...[
                          const SizedBox(width: 4),
                          TextButton.icon(
                            key: Key('quotation-edit-${quotation.id}'),
                            style: compactActionStyle,
                            onPressed: () => onEdit(quotation),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                          ),
                        ],
                        if (family.canRevise(quotation)) ...[
                          const SizedBox(width: 4),
                          TextButton.icon(
                            key: Key('quotation-revise-${quotation.id}'),
                            style: compactActionStyle,
                            onPressed: () => onRevise(quotation),
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text('Revise'),
                          ),
                        ],
                        _buildActionMenu(context, family, quotation),
                      ],
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    BuildContext context,
    QuotationFamily family,
    Quotation quotation,
  ) {
    final canDelete = family.canDelete(quotation);
    return PopupMenuButton<String>(
      key: Key('quotation-actions-${quotation.id}'),
      tooltip: 'More actions',
      icon: const Icon(Icons.more_vert, color: AppColors.mutedText),
      onSelected: (value) {
        switch (value) {
          case 'share':
            onShare(quotation);
            break;
          case 'duplicate':
            onDuplicate(quotation);
            break;
          case 'delete':
            _confirmDelete(context, quotation);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'share',
          child: _MenuItem(icon: Icons.share_outlined, label: 'Share'),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: _MenuItem(icon: Icons.copy_outlined, label: 'Duplicate'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          enabled: canDelete,
          child: _MenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            destructive: true,
            disabled: !canDelete,
          ),
        ),
      ],
    );
  }

  List<_QuotationRow> get _rows => [
    for (final family in families)
      for (final quotation in family.members) _QuotationRow(family, quotation),
  ];

  Future<void> _confirmDelete(BuildContext context, Quotation quotation) async {
    final confirm = await AppDialogs.showConfirm(
      context,
      title: 'Delete Quotation',
      message:
          'Are you sure you want to delete ${quotation.displayQuotationNumber} for ${quotation.customerInfo.name}?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirm) onDelete(quotation);
  }
}

class _QuotationRow {
  const _QuotationRow(this.family, this.quotation);

  final QuotationFamily family;
  final Quotation quotation;
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? Theme.of(context).disabledColor
        : destructive
        ? Colors.red
        : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
