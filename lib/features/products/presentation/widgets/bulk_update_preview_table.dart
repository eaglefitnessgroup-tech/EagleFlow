import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eagleflow/app/theme/app_colors.dart';
import '../../domain/bulk_update_models.dart';
import '../../domain/product_condition.dart';

class BulkUpdatePreviewTable extends StatelessWidget {
  final List<BulkProductUpdatePreviewRow> rows;

  const BulkUpdatePreviewTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No data rows found in the file.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PreviewCard(row: row),
                  ),
                )
                .toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columnSpacing: 24,
            dataRowMinHeight: 48,
            dataRowMaxHeight: double.infinity,
            columns: const [
              DataColumn(label: Text('Excel Row')),
              DataColumn(label: Text('Product Code')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Changes / Reason')),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    color: WidgetStateProperty.all(_rowBackground(row.status)),
                    cells: [
                      DataCell(Text(row.sourceRowNumber.toString())),
                      DataCell(Text(row.originalProductCode.trim())),
                      DataCell(_StatusBadge(status: row.status)),
                      DataCell(
                        SizedBox(width: 430, child: _ChangesOrReason(row: row)),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  static Color _rowBackground(BulkProductUpdateRowStatus status) {
    switch (status) {
      case BulkProductUpdateRowStatus.valid:
        return AppColors.statusApprovedBg.withValues(alpha: 0.35);
      case BulkProductUpdateRowStatus.noChanges:
        return Colors.white;
      case BulkProductUpdateRowStatus.unknownProduct:
        return AppColors.statusPendingBg.withValues(alpha: 0.45);
      case BulkProductUpdateRowStatus.duplicateCode:
      case BulkProductUpdateRowStatus.invalid:
        return AppColors.statusRejectedBg.withValues(alpha: 0.45);
    }
  }
}

class _PreviewCard extends StatelessWidget {
  final BulkProductUpdatePreviewRow row;

  const _PreviewCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BulkUpdatePreviewTable._rowBackground(row.status),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.originalProductCode.trim(),
                  key: Key('preview_code_${row.sourceRowNumber}'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              _StatusBadge(status: row.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Excel Row ${row.sourceRowNumber}',
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 10),
          _ChangesOrReason(row: row),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BulkProductUpdateRowStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(status);
    return Container(
      key: Key('status_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChangesOrReason extends StatelessWidget {
  final BulkProductUpdatePreviewRow row;

  const _ChangesOrReason({required this.row});

  @override
  Widget build(BuildContext context) {
    if (row.status == BulkProductUpdateRowStatus.valid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row.changes
            .map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      change.displayLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatValue(change.fieldKey, change.oldValue)} → '
                      '${_formatValue(change.fieldKey, change.newValue)}',
                      key: Key(
                        'change_${row.sourceRowNumber}_${change.fieldKey}',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    final reason = row.status == BulkProductUpdateRowStatus.noChanges
        ? 'No changes detected.'
        : row.validationReason ?? 'This row cannot be updated.';
    return Text(
      reason,
      key: Key('row_reason_${row.sourceRowNumber}'),
      style: TextStyle(
        color: row.status == BulkProductUpdateRowStatus.noChanges
            ? AppColors.mutedText
            : _statusStyle(row.status).foreground,
        fontSize: 13,
      ),
    );
  }

  static String _formatValue(String fieldKey, Object? value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is ProductCondition) return value.displayLabel;
    if (fieldKey == 'sellingPrice' && value is num) {
      return 'AED ${NumberFormat('#,##0.00').format(value)}';
    }
    return value.toString();
  }
}

_StatusStyle _statusStyle(BulkProductUpdateRowStatus status) {
  switch (status) {
    case BulkProductUpdateRowStatus.valid:
      return const _StatusStyle(
        'Valid',
        AppColors.statusApprovedBg,
        AppColors.statusApprovedText,
      );
    case BulkProductUpdateRowStatus.noChanges:
      return const _StatusStyle(
        'No Changes',
        AppColors.statusDraftBg,
        AppColors.statusDraftText,
      );
    case BulkProductUpdateRowStatus.unknownProduct:
      return const _StatusStyle(
        'Unknown Product',
        AppColors.statusPendingBg,
        AppColors.statusPendingText,
      );
    case BulkProductUpdateRowStatus.duplicateCode:
      return const _StatusStyle(
        'Duplicate Code',
        AppColors.statusRejectedBg,
        AppColors.statusRejectedText,
      );
    case BulkProductUpdateRowStatus.invalid:
      return const _StatusStyle(
        'Invalid',
        AppColors.statusRejectedBg,
        AppColors.statusRejectedText,
      );
  }
}

class _StatusStyle {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusStyle(this.label, this.background, this.foreground);
}
