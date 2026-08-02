import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../domain/quotation.dart';
import '../../../application/quotation_calculator.dart';
import 'quotation_status_badge.dart';

class QuotationListView extends StatelessWidget {
  final List<Quotation> quotations;
  final ValueChanged<Quotation> onView;
  final ValueChanged<Quotation> onEdit;
  final ValueChanged<Quotation> onDuplicate;
  final ValueChanged<Quotation> onShare;
  final ValueChanged<Quotation> onDelete;
  final VoidCallback onCreate;

  const QuotationListView({
    super.key,
    required this.quotations,
    required this.onView,
    required this.onEdit,
    required this.onDuplicate,
    required this.onShare,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    if (quotations.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quotations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildMobileCard(context, quotations[index]),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 48,
            color: AppColors.mutedText,
          ),
          const SizedBox(height: 16),
          const Text(
            'No quotations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first quotation to get started.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Quotation'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, Quotation quotation) {
    final formatter = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quotation.quotationNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                ),
                QuotationStatusBadge(status: quotation.status),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileRow('Customer', quotation.customerInfo.name),
                const SizedBox(height: 12),
                _buildMobileRow('Date', dateFmt.format(quotation.createdDate)),
                const SizedBox(height: 12),
                _buildMobileRow(
                  'Amount',
                  'AED ${formatter.format(QuotationCalculator.calculateGrandTotal(QuotationCalculator.calculateSubtotal(quotation.lineItems), quotation.charges))}',
                  isBold: true,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => onView(quotation),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  label: const Text('View Quotation'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.mutedText),
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        onEdit(quotation);
                        break;
                      case 'share':
                        onShare(quotation);
                        break;
                      case 'duplicate':
                        onDuplicate(quotation);
                        break;
                      case 'delete':
                        _confirmDelete(context, quotation, true);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Share PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
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
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.charcoal : AppColors.mutedText,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final formatter = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
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
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: quotations.map((q) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    q.quotationNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(dateFmt.format(q.createdDate))),
                DataCell(Text(q.customerInfo.name)),
                DataCell(
                  Text(q.salespersonId.isNotEmpty ? q.salespersonId : '—'),
                ),
                DataCell(
                  Text(
                    'AED ${formatter.format(QuotationCalculator.calculateGrandTotal(QuotationCalculator.calculateSubtotal(q.lineItems), q.charges))}',
                  ),
                ),
                DataCell(QuotationStatusBadge(status: q.status)),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.mutedText,
                      ),
                      onSelected: (val) {
                        switch (val) {
                          case 'view':
                            onView(q);
                            break;
                          case 'edit':
                            onEdit(q);
                            break;
                          case 'share':
                            onShare(q);
                            break;
                          case 'duplicate':
                            onDuplicate(q);
                            break;
                          case 'delete':
                            _confirmDelete(context, q, false);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Share PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Quotation quotation,
    bool isMobile,
  ) {
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete Quotation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete ${quotation.quotationNumber} for ${quotation.customerInfo.name}?',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete(quotation);
                        },
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Quotation'),
          content: Text(
            'Are you sure you want to delete ${quotation.quotationNumber} for ${quotation.customerInfo.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                onDelete(quotation);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }
}
