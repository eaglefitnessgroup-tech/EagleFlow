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
  final ValueChanged<Quotation> onDownload;
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
    required this.onDownload,
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
        if (constraints.maxWidth < 1200) {
          final rows = _rows;
          return ListView.separated(
            key: const Key('quotation-mobile-list'),
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
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildDirectActions(context, family, quotation),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
    final rows = _rows;

    return Container(
      key: const Key('quotation-desktop-table'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          headingRowHeight: 44,
          headingTextStyle: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          dataTextStyle: const TextStyle(
            color: AppColors.charcoal,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primarySoft.withValues(alpha: 0.32);
            }
            return AppColors.surface;
          }),
          dividerThickness: 0.75,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 58,
          horizontalMargin: 20,
          columnSpacing: 20,
          columns: const [
            DataColumn(
              label: Text('QT No.', key: Key('quotation-header-number')),
              headingRowAlignment: MainAxisAlignment.start,
              columnWidth: FixedColumnWidth(190),
            ),
            DataColumn(
              label: Text('Date', key: Key('quotation-header-date')),
              headingRowAlignment: MainAxisAlignment.start,
              columnWidth: FixedColumnWidth(128),
            ),
            DataColumn(
              label: Flexible(
                child: Text(
                  'Customer',
                  key: Key('quotation-header-customer'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              headingRowAlignment: MainAxisAlignment.start,
              columnWidth: FlexColumnWidth(1.4),
            ),
            DataColumn(
              label: Flexible(
                child: Text(
                  'Salesperson',
                  key: Key('quotation-header-salesperson'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              headingRowAlignment: MainAxisAlignment.start,
              columnWidth: FlexColumnWidth(1),
            ),
            DataColumn(
              label: Text('Amount', key: Key('quotation-header-amount')),
              numeric: true,
              headingRowAlignment: MainAxisAlignment.start,
              columnWidth: FixedColumnWidth(150),
            ),
            DataColumn(
              label: Text('Actions', key: Key('quotation-header-actions')),
              headingRowAlignment: MainAxisAlignment.end,
              columnWidth: FixedColumnWidth(400),
            ),
          ],
          rows: rows.map((row) {
            final quotation = row.quotation;
            final family = row.family;
            return DataRow(
              key: ValueKey('quotation-row-${quotation.id}'),
              onSelectChanged: (_) => onView(quotation),
              cells: [
                DataCell(
                  Text(
                    quotation.displayQuotationNumber,
                    key: Key('quotation-number-${quotation.id}'),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Text(
                    dateFmt.format(quotation.createdDate),
                    key: Key('quotation-date-${quotation.id}'),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                DataCell(
                  Text(
                    quotation.customerInfo.name,
                    key: Key('quotation-customer-${quotation.id}'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    salespersonNames[quotation.salespersonId] ??
                        (quotation.salespersonId.isNotEmpty
                            ? quotation.salespersonId
                            : '—'),
                    key: Key('quotation-salesperson-${quotation.id}'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    'AED ${formatter.format(QuotationCalculator.calculateGrandTotal(quotation.lineItems, quotation.charges))}',
                    key: Key('quotation-amount-${quotation.id}'),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildDirectActions(
                      context,
                      family,
                      quotation,
                      style: compactActionStyle,
                      iconSize: 16,
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

  Widget _buildDirectActions(
    BuildContext context,
    QuotationFamily family,
    Quotation quotation, {
    ButtonStyle? style,
    double iconSize = 16,
  }) {
    final canEdit = family.canEdit(quotation);
    final canDelete = family.canDelete(quotation);

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        _buildTextActionButton(
          key: Key('quotation-view-${quotation.id}'),
          style: style,
          onPressed: () => onView(quotation),
          icon: Icons.visibility_outlined,
          iconSize: iconSize,
          label: 'View',
        ),
        _buildTextActionButton(
          key: Key('quotation-edit-${quotation.id}'),
          style: style,
          onPressed: canEdit ? () => onEdit(quotation) : null,
          icon: Icons.edit_outlined,
          iconSize: iconSize,
          label: 'Edit',
        ),
        _buildTextActionButton(
          key: Key('quotation-revise-${quotation.id}'),
          style: style,
          onPressed: family.canRevise(quotation)
              ? () => onRevise(quotation)
              : null,
          icon: Icons.history,
          iconSize: iconSize,
          label: 'Revise',
        ),
        _buildIconActionButton(
          key: Key('quotation-download-${quotation.id}'),
          onPressed: () => onDownload(quotation),
          icon: Icons.download_outlined,
          iconSize: iconSize,
          tooltip: 'Download quotation',
          compact: style != null,
        ),
        _buildIconActionButton(
          key: Key('quotation-delete-${quotation.id}'),
          onPressed: canDelete
              ? () => _confirmDelete(context, quotation)
              : null,
          icon: Icons.delete_outline,
          iconSize: iconSize,
          tooltip: 'Delete quotation',
          compact: style != null,
        ),
        _buildActionMenu(quotation, iconSize: iconSize, compact: style != null),
      ],
    );
  }

  Widget _buildTextActionButton({
    required Key key,
    required VoidCallback? onPressed,
    required IconData icon,
    required double iconSize,
    required String label,
    ButtonStyle? style,
  }) {
    final stateStyle = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.mutedText.withValues(alpha: 0.42);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primaryDark;
        }
        return AppColors.primaryBlue;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primarySoft.withValues(alpha: 0.65);
        }
        return Colors.transparent;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return AppColors.primarySoft;
        }
        return Colors.transparent;
      }),
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      animationDuration: const Duration(milliseconds: 140),
    );

    return TextButton(
      key: key,
      style: stateStyle.merge(style),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildIconActionButton({
    required Key key,
    required VoidCallback? onPressed,
    required IconData icon,
    required double iconSize,
    required String tooltip,
    required bool compact,
  }) {
    final size = compact ? 32.0 : 40.0;
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        key: key,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: iconSize),
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(size)),
          maximumSize: WidgetStatePropertyAll(Size.square(size)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.mutedText.withValues(alpha: 0.38);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.charcoal;
            }
            return AppColors.mutedText;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.transparent;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primarySoft.withValues(alpha: 0.65);
            }
            return Colors.transparent;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.transparent;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primarySoft;
            }
            return Colors.transparent;
          }),
          mouseCursor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    Quotation quotation, {
    required double iconSize,
    required bool compact,
  }) {
    final size = compact ? 32.0 : 40.0;
    return PopupMenuButton<String>(
      key: Key('quotation-actions-${quotation.id}'),
      tooltip: 'More actions',
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      splashRadius: 18,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.square(size)),
        maximumSize: WidgetStatePropertyAll(Size.square(size)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.charcoal
              : AppColors.mutedText,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.primarySoft.withValues(alpha: 0.65)
              : Colors.transparent,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? AppColors.primarySoft
              : Colors.transparent,
        ),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        animationDuration: const Duration(milliseconds: 140),
      ),
      icon: Icon(Icons.more_vert, size: iconSize),
      onSelected: (value) {
        switch (value) {
          case 'share':
            onShare(quotation);
            break;
          case 'duplicate':
            onDuplicate(quotation);
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
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }
}
