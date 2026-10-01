import 'dart:typed_data';

import '../../../../core/utils/app_snackbars.dart';
import '../../../../core/utils/file_download_util.dart';
import '../../../../core/utils/pdf_share_helper.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/eagle_bottom_nav.dart';
import '../domain/quotation.dart';
import '../application/quotation_controller.dart';
import '../application/quotation_family.dart';
import 'widgets/previous/quotations_summary_row.dart';
import 'widgets/previous/quotation_filter_bar.dart';
import 'widgets/previous/quotation_list_view.dart';
import '../application/quotation_calculator.dart';
import '../application/quotation_pdf_service.dart';
import '../application/salesperson_name_resolver.dart';
import '../../../../core/di/service_locator.dart';
import 'quotation_preview_screen.dart';

typedef PreviousQuotationPdfGenerator =
    Future<Uint8List> Function(Quotation quotation);
typedef PreviousQuotationPdfDownloader =
    Future<void> Function({required List<int> bytes, required String filename});

int countRecentQuotations(List<Quotation> quotations, {DateTime? now}) {
  final referenceDate = now ?? DateTime.now();
  final cutoffDate = referenceDate.subtract(const Duration(days: 30));

  return quotations.where((quotation) {
    return !quotation.createdDate.isBefore(cutoffDate) &&
        !quotation.createdDate.isAfter(referenceDate);
  }).length;
}

int countRecentQuotationFamilies(
  List<QuotationFamily> families, {
  DateTime? now,
}) {
  final referenceDate = now ?? DateTime.now();
  final cutoffDate = referenceDate.subtract(const Duration(days: 30));

  return families.where((family) {
    final quotation = family.latest;
    return !quotation.createdDate.isBefore(cutoffDate) &&
        !quotation.createdDate.isAfter(referenceDate);
  }).length;
}

class PreviousQuotationsScreen extends StatefulWidget {
  const PreviousQuotationsScreen({
    super.key,
    this.pdfGenerator,
    this.pdfShareHelper,
    this.pdfDownloader,
  });

  final PreviousQuotationPdfGenerator? pdfGenerator;
  final PdfShareHelper? pdfShareHelper;
  final PreviousQuotationPdfDownloader? pdfDownloader;

  @override
  State<PreviousQuotationsScreen> createState() =>
      _PreviousQuotationsScreenState();
}

class _PreviousQuotationsScreenState extends State<PreviousQuotationsScreen> {
  List<Quotation> _allQuotations = [];
  List<QuotationFamily> _allFamilies = [];
  List<QuotationFamily> _filteredFamilies = [];

  String _searchQuery = '';
  String _sortBy = 'Newest';

  bool _isLoading = true;
  String? _errorMessage;

  String _salespersonName(Quotation quotation) {
    return SalespersonNameResolver.resolve(
      salespersonId: quotation.salespersonId,
      currentUser: ServiceLocator().authController.currentUser,
    );
  }

  Map<String, String> get _salespersonNames {
    final user = ServiceLocator().authController.currentUser;
    return user == null ? const {} : {user.id: user.name};
  }

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
          _allFamilies = groupQuotationFamilies(data);
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
      final query = _searchQuery.trim().toLowerCase();
      bool matches(Quotation quotation) =>
          quotation.quotationNumber.toLowerCase().contains(query) ||
          quotation.displayQuotationNumber.toLowerCase().contains(query) ||
          (quotation.revisionNo > 0 &&
              'r${quotation.revisionNo}'.contains(query)) ||
          quotation.customerInfo.name.toLowerCase().contains(query) ||
          _salespersonName(quotation).toLowerCase().contains(query) ||
          quotation.salespersonId.toLowerCase().contains(query);

      _filteredFamilies = _allFamilies.where((family) {
        return query.isEmpty || family.members.any(matches);
      }).toList();

      _filteredFamilies.sort((a, b) {
        int primary;
        if (_sortBy == 'Newest') {
          primary = b.latest.createdDate.compareTo(a.latest.createdDate);
        } else if (_sortBy == 'Oldest') {
          primary = a.latest.createdDate.compareTo(b.latest.createdDate);
        } else {
          final totalA = QuotationCalculator.calculateGrandTotal(
            a.latest.lineItems,
            a.latest.charges,
          );
          final totalB = QuotationCalculator.calculateGrandTotal(
            b.latest.lineItems,
            b.latest.charges,
          );
          primary = _sortBy == 'Highest Amount'
              ? totalB.compareTo(totalA)
              : totalA.compareTo(totalB);
        }
        return primary != 0 ? primary : a.original.id.compareTo(b.original.id);
      });
    });
  }

  Future<void> _handleDelete(Quotation quotation) async {
    try {
      final repo = ServiceLocator().quotationRepository;
      await repo.deleteQuotation(quotation.id);
      await _loadQuotations();
      if (mounted) {
        AppSnackBars.showSuccess(context, 'Quotation deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBars.showError(
          context,
          'Failed to delete quotation. Please try again.',
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
        AppSnackBars.showSuccess(context, 'Quotation duplicated successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBars.showError(
          context,
          'Failed to duplicate quotation. Please try again.',
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

  Future<void> _handleRevise(Quotation quotation) async {
    setState(() => _isLoading = true);
    try {
      final repo = ServiceLocator().quotationRepository;
      final fullQuotation = await repo.getQuotationWithImages(quotation);
      final controller = QuotationController.forRevision(fullQuotation);
      if (mounted) {
        setState(() => _isLoading = false);
        await Navigator.pushNamed(
          context,
          '/create-quotation',
          arguments: controller,
        );
        _loadQuotations();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBars.showError(
          context,
          'Failed to prepare quotation revision. Please try again.',
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
        final family = _allFamilies.firstWhere(
          (candidate) =>
              candidate.members.any((member) => member.id == quotation.id),
        );
        Navigator.pushNamed(
          context,
          '/quotation-preview',
          arguments: QuotationPreviewArguments(
            fullQuotation,
            readOnly: family.hasRevisions,
          ),
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

  Future<void> _handleShare(Quotation quotation) async {
    setState(() => _isLoading = true);

    try {
      final fullQuotation = await ServiceLocator().quotationRepository
          .getQuotationWithImages(quotation);
      if (!mounted) return;

      final generator = widget.pdfGenerator;
      final pdfBytes = generator == null
          ? await QuotationPdfService().generatePdf(fullQuotation)
          : await generator(fullQuotation);
      final sanitizedNumber = fullQuotation.displayQuotationNumber.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final filename = '$sanitizedNumber.pdf';

      try {
        await (widget.pdfShareHelper ?? PdfShareHelper()).sharePdf(
          bytes: pdfBytes,
          filename: filename,
        );
      } catch (_) {
        await (widget.pdfDownloader ?? FileDownloadUtil.save)(
          bytes: pdfBytes,
          filename: filename,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "File sharing isn't supported in this browser. "
                'The PDF was downloaded instead.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppSnackBars.showError(
          context,
          'Failed to share quotation PDF. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _allFamilies.length;
    final recent = countRecentQuotationFamilies(_allFamilies);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: isMobile
          ? const EagleBottomNav(currentIndex: 2)
          : null,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(context),
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
                  Column(
                    children: [
                      QuotationsSummaryRow(
                        totalCount: total,
                        recentCount: recent,
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Center(child: Text('No quotations found.')),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuotationsSummaryRow(
                        totalCount: total,
                        recentCount: recent,
                      ),
                      const SizedBox(height: 24),
                      QuotationFilterBar(
                        searchQuery: _searchQuery,
                        sortBy: _sortBy,
                        onSearchChanged: (val) {
                          _searchQuery = val;
                          _applyFilters();
                        },
                        onSortChanged: (val) {
                          _sortBy = val;
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildResultCount(_filteredFamilies.length, total),
                      QuotationListView(
                        families: _filteredFamilies,
                        salespersonNames: _salespersonNames,
                        onView: _handleView,
                        onEdit: _handleEdit,
                        onRevise: _handleRevise,
                        onDuplicate: _handleDuplicate,
                        onShare: _handleShare,
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
          children: [
            Expanded(child: titleContent),
            const SizedBox(width: 24),
            actionButton,
          ],
        );
      },
    );
  }
}
