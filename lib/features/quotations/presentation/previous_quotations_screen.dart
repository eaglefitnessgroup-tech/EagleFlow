import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../domain/quotation.dart';
import '../domain/quotation_status.dart';
import '../domain/customer_info.dart';
import '../domain/quotation_charges.dart';
import 'widgets/previous/quotations_summary_row.dart';
import 'widgets/previous/quotation_filter_bar.dart';
import 'widgets/previous/quotation_list_view.dart';
import '../application/quotation_calculator.dart';
import '../../../../core/di/service_locator.dart';

class PreviousQuotationsScreen extends StatefulWidget {
  const PreviousQuotationsScreen({super.key});

  @override
  State<PreviousQuotationsScreen> createState() =>
      _PreviousQuotationsScreenState();
}

class _PreviousQuotationsScreenState extends State<PreviousQuotationsScreen> {
  List<Quotation> _allQuotations = [];
  List<Quotation> _filteredQuotations = [];

  String _searchQuery = '';
  QuotationStatus? _selectedStatus;
  String _sortBy = 'Newest';

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ServiceLocator().quotationRepository;
      final data = await repo.getAllQuotations();
      if (mounted) {
        setState(() {
          _allQuotations = data;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
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

  Future<void> _handleDelete(Quotation quotation) async {
    try {
      final repo = ServiceLocator().quotationRepository;
      await repo.deleteQuotation(quotation.id);
      _loadQuotations();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quotation deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete quotation. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _handleDuplicate(Quotation quotation) async {
    try {
      final repo = ServiceLocator().quotationRepository;
      await repo.duplicateQuotation(quotation);
      _loadQuotations();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quotation duplicated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate quotation. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _handleEdit(Quotation quotation) async {
    setState(() => _isLoading = true);
    try {
      final repo = ServiceLocator().quotationRepository;
      final fullQuotation = await repo.getQuotationWithImages(quotation);
      if (mounted) {
        setState(() => _isLoading = false);
        await Navigator.pushNamed(
          context,
          '/create-quotation',
          arguments: fullQuotation,
        );
        _loadQuotations();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load quotation for editing. Please check your connection.',
            ),
          ),
        );
      }
    }
  }

  void _handleView(Quotation quotation) async {
    setState(() => _isLoading = true);
    try {
      final repo = ServiceLocator().quotationRepository;
      final fullQuotation = await repo.getQuotationWithImages(quotation);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamed(
          context,
          '/quotation-preview',
          arguments: fullQuotation,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load quotation preview. Please check your connection.',
            ),
          ),
        );
      }
    }
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
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadQuotations,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_allQuotations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: Text('No quotations found.')),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        onEdit: _handleEdit,
                        onDuplicate: _handleDuplicate,
                        onShare: (q) => _showMockActionToast('PDF sharing'),
                        onDelete: _handleDelete,
                        onCreate: () async {
                          await Navigator.pushNamed(
                            context,
                            '/create-quotation',
                          );
                          _loadQuotations();
                        },
                      ),
                    ],
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

        final titleContent = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.charcoal),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  }
                },
              ),
            ),
            Expanded(
              child: Column(
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
              ),
            ),
          ],
        );

        final actionButton = FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: isMobile
                ? null
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () async {
            await Navigator.pushNamed(context, '/create-quotation');
            _loadQuotations();
          },
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
