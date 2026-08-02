import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../domain/quotation.dart';
import '../domain/quotation_status.dart';
import '../domain/customer_info.dart';
import '../domain/quotation_charges.dart';
import 'widgets/previous/quotations_summary_row.dart';
import 'widgets/previous/quotation_filter_bar.dart';
import 'widgets/previous/quotation_list_view.dart';
import '../application/quotation_controller.dart';
import '../application/quotation_calculator.dart';

class PreviousQuotationsScreen extends StatefulWidget {
  const PreviousQuotationsScreen({super.key});

  @override
  State<PreviousQuotationsScreen> createState() =>
      _PreviousQuotationsScreenState();
}

class _PreviousQuotationsScreenState extends State<PreviousQuotationsScreen> {
  late List<Quotation> _allQuotations;
  late List<Quotation> _filteredQuotations;

  String _searchQuery = '';
  QuotationStatus? _selectedStatus;
  String _sortBy = 'Newest';

  @override
  void initState() {
    super.initState();
    _generateMockData();
    _applyFilters();
  }

  void _generateMockData() {
    final now = DateTime.now();
    _allQuotations = [
      Quotation(
        id: '1',
        quotationNumber: 'QT-0001-26',
        customerInfo: const CustomerInfo(name: 'Acme Corp'),
        salespersonId: 'John Doe',
        createdDate: now,
        modifiedDate: now,
        validUntil: now.add(const Duration(days: 30)),
        expectedDelivery: now.add(const Duration(days: 7)),
        status: QuotationStatus.draft,
        charges: const QuotationCharges(deliveryCharges: 100),
      ),
      Quotation(
        id: '2',
        quotationNumber: 'QT-0002-26',
        customerInfo: const CustomerInfo(name: 'Wayne Enterprises'),
        salespersonId: 'Jane Smith',
        createdDate: now.subtract(const Duration(days: 2)),
        modifiedDate: now,
        validUntil: now.add(const Duration(days: 28)),
        expectedDelivery: now.add(const Duration(days: 5)),
        status: QuotationStatus.sent,
        charges: const QuotationCharges(
          deliveryCharges: 500,
          installationCharges: 200,
        ),
      ),
      Quotation(
        id: '3',
        quotationNumber: 'QT-0003-26',
        customerInfo: const CustomerInfo(name: 'Stark Industries'),
        salespersonId: 'Bruce Banner',
        createdDate: now.subtract(const Duration(days: 5)),
        modifiedDate: now,
        validUntil: now.add(const Duration(days: 25)),
        expectedDelivery: now.add(const Duration(days: 10)),
        status: QuotationStatus.approved,
        charges: const QuotationCharges(
          deliveryCharges: 1000,
          installationCharges: 5000,
        ),
      ),
      Quotation(
        id: '4',
        quotationNumber: 'QT-0004-26',
        customerInfo: const CustomerInfo(name: 'Oscorp'),
        salespersonId: 'Peter Parker',
        createdDate: now.subtract(const Duration(days: 10)),
        modifiedDate: now,
        validUntil: now.add(const Duration(days: 20)),
        expectedDelivery: now.add(const Duration(days: 14)),
        status: QuotationStatus.rejected,
        charges: const QuotationCharges(),
      ),
      Quotation(
        id: '5',
        quotationNumber: 'QT-0005-26',
        customerInfo: const CustomerInfo(name: 'Daily Bugle'),
        salespersonId: 'J. Jonah Jameson',
        createdDate: now.subtract(const Duration(days: 40)),
        modifiedDate: now,
        validUntil: now.subtract(const Duration(days: 10)),
        expectedDelivery: now,
        status: QuotationStatus.expired,
        charges: const QuotationCharges(deliveryCharges: 50),
      ),
    ];
  }

  void _applyFilters() {
    setState(() {
      _filteredQuotations = _allQuotations.where((q) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            q.quotationNumber.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            q.customerInfo.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            q.salespersonId.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesStatus =
            _selectedStatus == null || q.status == _selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();

      if (_sortBy == 'Newest') {
        _filteredQuotations.sort(
          (a, b) => b.createdDate.compareTo(a.createdDate),
        );
      } else if (_sortBy == 'Oldest') {
        _filteredQuotations.sort(
          (a, b) => a.createdDate.compareTo(b.createdDate),
        );
      } else if (_sortBy == 'Highest Amount' || _sortBy == 'Lowest Amount') {
        double calculateTotal(Quotation q) =>
            QuotationCalculator.calculateGrandTotal(
              QuotationCalculator.calculateVAT(
                QuotationCalculator.calculateSubtotal(q.lineItems),
                q.charges,
              ),
              q.charges,
            );

        if (_sortBy == 'Highest Amount') {
          _filteredQuotations.sort(
            (a, b) => calculateTotal(b).compareTo(calculateTotal(a)),
          );
        } else {
          _filteredQuotations.sort(
            (a, b) => calculateTotal(a).compareTo(calculateTotal(b)),
          );
        }
      }
    });
  }

  void _handleDelete(Quotation quotation) {
    setState(() {
      _allQuotations.removeWhere((q) => q.id == quotation.id);
      _applyFilters();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quotation ${quotation.quotationNumber} deleted (Mock).'),
      ),
    );
  }

  void _handleView(Quotation quotation) {
    Navigator.pushNamed(
      context,
      '/quotation-preview',
      arguments: QuotationController(quotation),
    );
  }

  void _showMockActionToast(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action will be available after quotation persistence is connected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _allQuotations.length;
    final drafts = _allQuotations
        .where((q) => q.status == QuotationStatus.draft)
        .length;
    final sent = _allQuotations
        .where((q) => q.status == QuotationStatus.sent)
        .length;
    final accepted = _allQuotations
        .where((q) => q.status == QuotationStatus.approved)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(context),
                const SizedBox(height: 24),
                QuotationsSummaryRow(
                  totalCount: total,
                  draftCount: drafts,
                  sentCount: sent,
                  acceptedCount: accepted,
                ),
                const SizedBox(height: 24),
                QuotationFilterBar(
                  searchQuery: _searchQuery,
                  selectedStatus: _selectedStatus,
                  sortBy: _sortBy,
                  onSearchChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                  onStatusChanged: (val) {
                    _selectedStatus = val;
                    _applyFilters();
                  },
                  onSortChanged: (val) {
                    _sortBy = val;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 24),
                _buildResultCount(_filteredQuotations.length, total),
                QuotationListView(
                  quotations: _filteredQuotations,
                  onView: _handleView,
                  onEdit: (q) => _showMockActionToast('Edit'),
                  onDuplicate: (q) => _showMockActionToast('Duplicate'),
                  onShare: (q) => _showMockActionToast('PDF sharing'),
                  onDelete: _handleDelete,
                  onCreate: () =>
                      Navigator.pushNamed(context, '/create-quotation'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCount(int filteredCount, int totalCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        filteredCount == totalCount
            ? 'Showing $totalCount quotations'
            : 'Showing $filteredCount of $totalCount quotations',
        style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final titleContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Previous Quotations',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'View, manage and reuse saved quotations',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ],
        );

        final actionButton = FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: isMobile
                ? null
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () => Navigator.pushNamed(context, '/create-quotation'),
          icon: const Icon(Icons.add),
          label: const Text('Create Quotation'),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleContent,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: actionButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [titleContent, actionButton],
        );
      },
    );
  }
}
