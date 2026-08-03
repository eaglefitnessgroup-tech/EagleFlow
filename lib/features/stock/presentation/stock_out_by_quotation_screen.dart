import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../quotations/domain/quotation.dart';
import '../../quotations/domain/quotation_line_item.dart';

class StockOutByQuotationScreen extends StatefulWidget {
  const StockOutByQuotationScreen({super.key});

  @override
  State<StockOutByQuotationScreen> createState() =>
      _StockOutByQuotationScreenState();
}

class _StockOutByQuotationScreenState extends State<StockOutByQuotationScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;
  Quotation? _quotation;

  bool _isLoadingStock = false;
  final Map<String, int> _availableStock = {};
  final Map<String, bool> _missingProducts = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStockData() async {
    if (_quotation == null) return;
    final items = _quotation!.lineItems;
    final eligibleItems = items
        .where((i) => !i.isCustom && i.productId != null)
        .toList();
    if (eligibleItems.isEmpty) return;

    setState(() {
      _isLoadingStock = true;
      _availableStock.clear();
      _missingProducts.clear();
    });

    final productRepo = ServiceLocator().productRepository;
    final stockController = ServiceLocator().stockController;

    for (var item in eligibleItems) {
      try {
        final product = await productRepo.getProductById(item.productId!);
        if (product == null) {
          _missingProducts[item.id] = true;
        } else {
          final stock = await stockController.getCurrentStock(product);
          _availableStock[item.id] = stock;
        }
      } catch (e) {
        _missingProducts[item.id] = true;
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingStock = false;
      });
    }
  }

  Future<void> _lookupQuotation() async {
    final query = _controller.text.trim().toUpperCase();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _quotation = null;
      _availableStock.clear();
      _missingProducts.clear();
    });

    try {
      final repo = ServiceLocator().quotationRepository;
      final result = await repo.getQuotationByNumber(query);
      setState(() {
        if (result == null) {
          _error = 'Quotation not found.';
        } else {
          _quotation = result;
        }
      });
      if (result != null && !result.isStockOutProcessed) {
        await _loadStockData();
      }
    } catch (e) {
      setState(() {
        _error = 'Error looking up quotation: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _canConfirm {
    if (_isLoadingStock) return false;
    final items = _quotation?.lineItems ?? [];
    final eligibleItems = items
        .where((i) => !i.isCustom && i.productId != null)
        .toList();
    if (eligibleItems.isEmpty) return false;

    for (var item in eligibleItems) {
      if (_missingProducts[item.id] == true) return false;
      final avail = _availableStock[item.id];
      if (avail == null || avail < item.quantity) return false;
    }
    return true;
  }

  Future<void> _confirmStockOut() async {
    if (_quotation == null) return;

    final eligibleItems = _quotation!.lineItems
        .where((i) => !i.isCustom && i.productId != null)
        .toList();

    int totalQty = eligibleItems.fold(0, (sum, item) => sum + item.quantity);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Stock Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quotation number: ${_quotation!.quotationNumber}'),
            const SizedBox(height: 8),
            Text('Customer name: ${_quotation!.customerInfo.name}'),
            const SizedBox(height: 8),
            Text('Eligible stock items: ${eligibleItems.length}'),
            const SizedBox(height: 8),
            Text('Total quantity to be deducted: $totalQty'),
            const SizedBox(height: 16),
            const Text(
              'This action will deduct stock for all eligible quotation items and cannot be repeated.',
              style: TextStyle(
                color: AppColors.statusRejectedText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final service = ServiceLocator().stockOutByQuotationService;
      final result = await service.processStockOut(_quotation!.quotationNumber);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock Out completed successfully.'),
              backgroundColor: AppColors.statusApprovedText,
            ),
          );
          _lookupQuotation();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.statusRejectedText,
            ),
          );
          _loadStockData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.statusRejectedText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Stock Out by Quotation',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quotation Number',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter quotation number',
                      helperText: 'Example: QT-0001-26',
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
                        borderSide: const BorderSide(
                          color: AppColors.primaryBlue,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      if (_controller.text.trim().isNotEmpty && !_isLoading) {
                        _lookupQuotation();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _controller.text.trim().isEmpty || _isLoading
                          ? null
                          : _lookupQuotation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryBlue
                            .withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isLoading ? 'Searching...' : 'Find Quotation',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.statusRejectedText.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.statusRejectedText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.statusRejectedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_quotation != null) ...[
              const SizedBox(height: 24),
              if (_quotation!.isStockOutProcessed)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.statusPendingBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.statusPendingText.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.statusPendingText,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Stock Out has already been completed for this quotation.',
                          style: TextStyle(
                            color: AppColors.statusPendingText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildQuotationPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationPreview() {
    final items = _quotation!.lineItems;
    final eligibleItems = items
        .where((i) => !i.isCustom && i.productId != null)
        .toList();
    final customItems = items
        .where((i) => i.isCustom || i.productId == null)
        .toList();

    int itemsReady = 0;
    int itemsInsufficient = 0;
    int itemsMissing = 0;
    for (var item in eligibleItems) {
      if (_missingProducts[item.id] == true) {
        itemsMissing++;
      } else if (_availableStock.containsKey(item.id)) {
        if (_availableStock[item.id]! >= item.quantity) {
          itemsReady++;
        } else {
          itemsInsufficient++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quotation Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
              const Divider(height: 32),
              _buildDetailRow('Quotation Number', _quotation!.quotationNumber),
              const SizedBox(height: 16),
              _buildDetailRow('Customer Name', _quotation!.customerInfo.name),
              if (_quotation!.salespersonId.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow('Salesperson ID', _quotation!.salespersonId),
              ],
              const SizedBox(height: 16),
              _buildDetailRow('Total Line Items', '${items.length} items'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'QUOTATION ITEMS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.mutedText,
                letterSpacing: 1.2,
              ),
            ),
            IconButton(
              onPressed: _isLoadingStock ? null : _loadStockData,
              icon: const Icon(Icons.refresh),
              color: AppColors.primaryBlue,
              tooltip: 'Refresh Stock',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final isEligible = !item.isCustom && item.productId != null;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isEligible
                                  ? AppColors.charcoal
                                  : AppColors.mutedText,
                            ),
                          ),
                          if (item.productCode != null &&
                              item.productCode!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Code: ${item.productCode}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isEligible
                                  ? AppColors.primarySoft
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEligible
                                  ? 'Stock Item'
                                  : 'Custom Item — Not deducted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isEligible
                                    ? AppColors.primaryBlue
                                    : AppColors.mutedText,
                              ),
                            ),
                          ),
                          if (isEligible) ...[
                            const SizedBox(height: 12),
                            if (_isLoadingStock)
                              const LinearProgressIndicator(
                                backgroundColor: AppColors.border,
                                color: AppColors.primaryBlue,
                              ),
                            if (!_isLoadingStock &&
                                _missingProducts[item.id] == true)
                              const Text(
                                'Error: Product missing or unavailable',
                                style: TextStyle(
                                  color: AppColors.statusRejectedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (!_isLoadingStock &&
                                _availableStock.containsKey(item.id))
                              _buildStockStatus(
                                item,
                                _availableStock[item.id]!,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'x${item.quantity}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isEligible
                            ? AppColors.charcoal
                            : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (eligibleItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusRejectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.statusRejectedText.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.statusRejectedText,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'This quotation has no stock-linked products to deduct.',
                    style: TextStyle(
                      color: AppColors.statusRejectedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Eligible stock items:',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${eligibleItems.length}',
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (!_isLoadingStock) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items ready:',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                      Text(
                        '$itemsReady',
                        style: const TextStyle(
                          color: AppColors.statusApprovedText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (itemsInsufficient > 0 || itemsMissing > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Insufficient / missing:',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                        Text(
                          '${itemsInsufficient + itemsMissing}',
                          style: const TextStyle(
                            color: AppColors.statusRejectedText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                if (customItems.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custom/non-stock items:',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${customItems.length}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        if (eligibleItems.isNotEmpty) ...[
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _canConfirm && !_isProcessing
                  ? _confirmStockOut
                  : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isProcessing ? 'Processing...' : 'Confirm Stock Out',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryBlue.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStockStatus(QuotationLineItem item, int available) {
    final requiredQty = item.quantity;
    final remaining = available - requiredQty;
    final isSufficient = remaining >= 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSufficient
            ? AppColors.statusApprovedBg
            : AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSufficient
              ? AppColors.statusApprovedText.withValues(alpha: 0.3)
              : AppColors.statusRejectedText.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSufficient ? Icons.check_circle : Icons.error,
                size: 16,
                color: isSufficient
                    ? AppColors.statusApprovedText
                    : AppColors.statusRejectedText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSufficient
                      ? 'Available'
                      : 'Only $available units are available.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSufficient
                        ? AppColors.statusApprovedText
                        : AppColors.statusRejectedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStockStat('Required', '$requiredQty'),
              _buildStockStat('Available', '$available'),
              _buildStockStat(
                'Remaining',
                '$remaining',
                color: isSufficient ? null : AppColors.statusRejectedText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}
