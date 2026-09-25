import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:eagleflow/app/theme/app_colors.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/guards/admin_guard.dart';
import '../application/bulk_product_update_service.dart';
import '../domain/bulk_update_models.dart';
import '../domain/product.dart';
import 'folder_picker/folder_picker.dart';
import 'widgets/bulk_update_preview_table.dart';

typedef BulkUpdateFilePicker = Future<Map<String, List<int>>?> Function();
typedef CurrentProductsLoader = Future<List<Product>> Function();

class BulkUpdateProductsScreen extends StatelessWidget {
  final BulkProductUpdateService? service;
  final BulkProductWorkbookSaver? fileSaver;
  final BulkUpdateFilePicker? filePicker;
  final CurrentProductsLoader? currentProductsLoader;
  final BulkProductFieldsUpdater? productFieldsUpdater;

  const BulkUpdateProductsScreen({
    super.key,
    this.service,
    this.fileSaver,
    this.filePicker,
    this.currentProductsLoader,
    this.productFieldsUpdater,
  });

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: _BulkUpdateProductsContent(
        service: service,
        fileSaver: fileSaver,
        filePicker: filePicker,
        currentProductsLoader: currentProductsLoader,
        productFieldsUpdater: productFieldsUpdater,
      ),
    );
  }
}

class _BulkUpdateProductsContent extends StatefulWidget {
  final BulkProductUpdateService? service;
  final BulkProductWorkbookSaver? fileSaver;
  final BulkUpdateFilePicker? filePicker;
  final CurrentProductsLoader? currentProductsLoader;
  final BulkProductFieldsUpdater? productFieldsUpdater;

  const _BulkUpdateProductsContent({
    this.service,
    this.fileSaver,
    this.filePicker,
    this.currentProductsLoader,
    this.productFieldsUpdater,
  });

  @override
  State<_BulkUpdateProductsContent> createState() =>
      _BulkUpdateProductsContentState();
}

class _BulkUpdateProductsContentState
    extends State<_BulkUpdateProductsContent> {
  late final BulkProductUpdateService _service =
      widget.service ?? BulkProductUpdateService();

  List<BulkProductUpdatePreviewRow>? _previewRows;
  String? _selectedFileName;
  String? _validationError;
  bool _isParsing = false;
  bool _isDownloading = false;
  bool _isConfirming = false;
  bool _isUpdating = false;
  int _updateCurrent = 0;
  int _updateTotal = 0;
  BulkProductUpdateResult? _updateResult;
  String? _updateError;
  String? _refreshError;

  int get _validCount => _count(BulkProductUpdateRowStatus.valid);
  int get _noChangesCount => _count(BulkProductUpdateRowStatus.noChanges);
  int get _unknownCount => _count(BulkProductUpdateRowStatus.unknownProduct);
  int get _duplicateCount => _count(BulkProductUpdateRowStatus.duplicateCode);
  int get _invalidCount =>
      _count(BulkProductUpdateRowStatus.invalid) + _duplicateCount;
  bool get _hasValidChanges => _validCount > 0;
  bool get _isBusy =>
      _isParsing || _isDownloading || _isConfirming || _isUpdating;

  int _count(BulkProductUpdateRowStatus status) =>
      _previewRows?.where((row) => row.status == status).length ?? 0;

  Future<List<Product>> _loadFreshProducts() async {
    if (widget.currentProductsLoader != null) {
      return widget.currentProductsLoader!();
    }

    final controller = ServiceLocator().productMasterController;
    await controller.loadProducts();
    if (controller.error != null) {
      throw StateError(controller.error!);
    }
    return List<Product>.unmodifiable(controller.products);
  }

  Future<void> _downloadCurrentProducts() async {
    if (_isBusy) return;
    setState(() {
      _isDownloading = true;
    });

    try {
      final products = await _loadFreshProducts();
      await _service.downloadCurrentProductsWorkbook(
        products,
        fileSaver: widget.fileSaver,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current products Excel downloaded.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not download current products. Please try again.',
          ),
          backgroundColor: AppColors.statusRejectedText,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _selectUpdateFile() async {
    if (_isBusy) return;

    try {
      final picked = await (widget.filePicker ?? pickExcelFile)();
      if (picked == null || picked.isEmpty) return;

      final fileName = picked.keys.first;
      final bytes = picked.values.first;
      if (!mounted) return;
      setState(() {
        _selectedFileName = fileName;
        _previewRows = null;
        _validationError = null;
        _updateResult = null;
        _updateError = null;
        _refreshError = null;
        _isParsing = true;
      });

      final products = await _loadFreshProducts();
      final rows = fileName.toLowerCase().endsWith('.csv')
          ? _service.previewCsv(utf8.decode(bytes), currentProducts: products)
          : _service.previewExcel(bytes, currentProducts: products);

      if (!mounted) return;
      setState(() {
        _previewRows = rows;
        _isParsing = false;
      });
    } on FormatException catch (error) {
      _showValidationError(error.message);
    } catch (_) {
      _showValidationError(
        'Could not validate the selected file. Please check the format and try again.',
      );
    }
  }

  void _showValidationError(String message) {
    if (!mounted) return;
    setState(() {
      _previewRows = null;
      _validationError = message;
      _isParsing = false;
    });
  }

  Future<void> _confirmAndUpdateProducts() async {
    if (_isBusy || !_hasValidChanges || _previewRows == null) return;

    setState(() {
      _isConfirming = true;
    });
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'Update $_validCount ${_validCount == 1 ? 'product' : 'products'}?',
            ),
            content: const Text(
              'Only the displayed changes will be applied.\n\n'
              'Product Code, Opening Stock, and images will remain unchanged.',
            ),
            actions: [
              TextButton(
                key: const Key('cancel_bulk_update_btn'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('confirm_bulk_update_btn'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Update Products'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    setState(() {
      _isConfirming = false;
    });
    if (!confirmed) return;

    await _executeUpdates();
  }

  Future<void> _executeUpdates() async {
    if (_isUpdating || _previewRows == null) return;

    final rows = List<BulkProductUpdatePreviewRow>.unmodifiable(_previewRows!);
    setState(() {
      _isUpdating = true;
      _updateCurrent = 0;
      _updateTotal = _validCount;
      _updateResult = null;
      _updateError = null;
      _refreshError = null;
    });

    try {
      final result = await _service.executeUpdates(
        previewRows: rows,
        loadFreshProducts: _loadFreshProducts,
        updateProductFields:
            widget.productFieldsUpdater ??
            ServiceLocator().productRepository.updateProductFields,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _updateCurrent = current;
            _updateTotal = total;
          });
        },
      );

      String? refreshError;
      try {
        await _loadFreshProducts();
      } catch (_) {
        refreshError =
            'Products were updated, but the final refresh failed. Refresh the product list before making further changes.';
      }

      if (!mounted) return;
      setState(() {
        _updateResult = result;
        _refreshError = refreshError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updateError =
            'Could not load fresh product data. No updates were attempted.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bulk Update Products'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildActionCard(),
                      if (_isParsing) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(
                          key: Key('bulk_update_parsing_indicator'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Validating file…',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                      if (_validationError != null) ...[
                        const SizedBox(height: 16),
                        _buildValidationError(),
                      ],
                      if (!_isParsing &&
                          _validationError == null &&
                          _previewRows == null) ...[
                        const SizedBox(height: 28),
                        const _EmptyPreviewState(),
                      ],
                      if (_previewRows != null) ...[
                        const SizedBox(height: 18),
                        _BulkUpdateSummary(
                          valid: _validCount,
                          noChanges: _noChangesCount,
                          unknown: _unknownCount,
                          invalid: _invalidCount,
                        ),
                        const SizedBox(height: 18),
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: BulkUpdatePreviewTable(rows: _previewRows!),
                          ),
                        ),
                      ],
                      if (_isUpdating) ...[
                        const SizedBox(height: 18),
                        _BulkUpdateProgress(
                          current: _updateCurrent,
                          total: _updateTotal,
                        ),
                      ],
                      if (_updateError != null) ...[
                        const SizedBox(height: 18),
                        _BulkUpdateMessage(
                          key: const Key('bulk_update_execution_error'),
                          message: _updateError!,
                          isError: true,
                        ),
                      ],
                      if (_updateResult != null) ...[
                        const SizedBox(height: 18),
                        _BulkUpdateResultSummary(result: _updateResult!),
                      ],
                      if (_refreshError != null) ...[
                        const SizedBox(height: 12),
                        _BulkUpdateMessage(
                          key: const Key('bulk_update_refresh_error'),
                          message: _refreshError!,
                          isError: true,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Tooltip(
                        message: _hasValidChanges
                            ? 'Apply the valid changes shown in the preview.'
                            : 'Select a file containing at least one valid change.',
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const Key('update_products_btn'),
                            onPressed: _hasValidChanges && !_isBusy
                                ? _confirmAndUpdateProducts
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                            child: Text(
                              _isUpdating
                                  ? 'Updating $_updateCurrent of $_updateTotal…'
                                  : 'Update Products',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isUpdating
                            ? 'Please keep this screen open until processing finishes.'
                            : 'Only valid changed rows will be updated after confirmation.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update existing products from Excel or CSV',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use Product Code to match existing products. Blank cells will keep the current value.',
              style: TextStyle(color: AppColors.mutedText, height: 1.4),
            ),
            const SizedBox(height: 4),
            const Text(
              'Product Code cannot be changed. Opening Stock and images are not updated here.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final downloadButton = OutlinedButton.icon(
                  key: const Key('download_current_products_btn'),
                  onPressed: _isBusy ? null : _downloadCurrentProducts,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('Download Current Products'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                );
                final selectButton = ElevatedButton.icon(
                  key: const Key('select_update_file_btn'),
                  onPressed: _isBusy ? null : _selectUpdateFile,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: Text(
                    _selectedFileName == null
                        ? 'Select Excel File'
                        : 'Choose Another File',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      downloadButton,
                      const SizedBox(height: 10),
                      selectButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: downloadButton),
                    const SizedBox(width: 12),
                    Expanded(child: selectButton),
                  ],
                );
              },
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    size: 15,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _selectedFileName!,
                      key: const Key('selected_update_file_name'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationError() {
    return Container(
      key: const Key('bulk_update_validation_error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.statusRejectedText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _validationError!,
              style: const TextStyle(color: AppColors.statusRejectedText),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreviewState extends StatelessWidget {
  const _EmptyPreviewState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('bulk_update_empty_state'),
      children: [
        Icon(Icons.table_view_outlined, size: 42, color: AppColors.border),
        SizedBox(height: 10),
        Text(
          'No update file selected.',
          style: TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Select an Excel or CSV file to validate and preview changes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
      ],
    );
  }
}

class _BulkUpdateSummary extends StatelessWidget {
  final int valid;
  final int noChanges;
  final int unknown;
  final int invalid;

  const _BulkUpdateSummary({
    required this.valid,
    required this.noChanges,
    required this.unknown,
    required this.invalid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bulk_update_summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryItem(
            key: const Key('summary_valid'),
            label: 'Valid Changes',
            count: valid,
            color: AppColors.statusApprovedText,
          ),
          _SummaryItem(
            key: const Key('summary_no_changes'),
            label: 'No Changes',
            count: noChanges,
            color: AppColors.statusDraftText,
          ),
          _SummaryItem(
            key: const Key('summary_unknown'),
            label: 'Unknown Codes',
            count: unknown,
            color: AppColors.statusPendingText,
          ),
          _SummaryItem(
            key: const Key('summary_invalid'),
            label: 'Invalid Rows',
            count: invalid,
            color: AppColors.statusRejectedText,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _BulkUpdateProgress extends StatelessWidget {
  final int current;
  final int total;

  const _BulkUpdateProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bulk_update_progress'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: total == 0 || current == 0 ? null : current / total,
          ),
          const SizedBox(height: 8),
          Text(
            current == 0
                ? 'Loading fresh product data…'
                : 'Updating $current of $total…',
            key: const Key('bulk_update_progress_text'),
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _BulkUpdateResultSummary extends StatelessWidget {
  final BulkProductUpdateResult result;

  const _BulkUpdateResultSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bulk_update_result_summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Update Results',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                'Succeeded: ${result.succeeded}',
                key: const Key('result_succeeded'),
                style: const TextStyle(color: AppColors.statusApprovedText),
              ),
              Text(
                'Skipped: ${result.skipped}',
                key: const Key('result_skipped'),
                style: const TextStyle(color: AppColors.statusPendingText),
              ),
              Text(
                'Failed: ${result.failed}',
                key: const Key('result_failed'),
                style: const TextStyle(color: AppColors.statusRejectedText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...result.rowResults.map(
            (row) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                key: Key('result_row_${row.sourceRowNumber}'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Row ${row.sourceRowNumber} / ${row.productCode}',
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _resultDescription(row),
                      style: TextStyle(color: _resultColor(row.status)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _resultDescription(BulkProductUpdateRowResult row) {
    switch (row.status) {
      case BulkProductUpdateRowResultStatus.succeeded:
        return row.reason ?? 'Updated successfully';
      case BulkProductUpdateRowResultStatus.skipped:
        return 'Skipped — ${row.reason ?? 'Not eligible for update'}';
      case BulkProductUpdateRowResultStatus.failed:
        return 'Failed — ${row.reason ?? 'Update failed'}';
    }
  }

  static Color _resultColor(BulkProductUpdateRowResultStatus status) {
    switch (status) {
      case BulkProductUpdateRowResultStatus.succeeded:
        return AppColors.statusApprovedText;
      case BulkProductUpdateRowResultStatus.skipped:
        return AppColors.statusPendingText;
      case BulkProductUpdateRowResultStatus.failed:
        return AppColors.statusRejectedText;
    }
  }
}

class _BulkUpdateMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const _BulkUpdateMessage({
    super.key,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? AppColors.statusRejectedBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? AppColors.statusRejectedText : AppColors.charcoal,
        ),
      ),
    );
  }
}
