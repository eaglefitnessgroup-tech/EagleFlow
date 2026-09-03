import re

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove QuotationSummary and QuotationStatus completely
content = re.sub(r'// Temporary structured models\s*class QuotationSummary \{.*?\}\s*enum QuotationStatus \{ pending, sent, approved \}\s*', '', content, flags=re.DOTALL)

# Add imports for Quotation, QuotationStatus, QuotationCalculator, intl
imports = """import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../quotations/domain/quotation.dart';
import '../../quotations/domain/quotation_status.dart';
import '../../quotations/application/quotation_calculator.dart';
"""
content = re.sub(r"import 'package:flutter/material\.dart';\s*import '\.\.\/\.\.\/\.\.\/app/routes/app_routes\.dart';\s*import '\.\.\/\.\.\/\.\.\/app/theme/app_colors\.dart';\s*import '\.\.\/\.\.\/\.\.\/core/di/service_locator\.dart';", imports, content)


# Modify state class
state_replacement = """class _DashboardScreenState extends State<DashboardScreen> {
  final int _currentIndex = 0;

  bool _isLoading = true;
  int _totalProducts = 0;
  int _todaysQuotations = 0;
  int _pendingQuotations = 0;
  int _lowStockItems = 0;
  List<Quotation> _recentQuotations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final productRepo = ServiceLocator().productRepository;
      final quotationRepo = ServiceLocator().quotationRepository;
      final stockController = ServiceLocator().stockController;

      final products = await productRepo.getAllProducts();
      final quotations = await quotationRepo.getAllQuotations();

      int lowStockCount = 0;
      // We can use Future.wait if needed, but doing it sequentially or batched is safer for local cache.
      // Since it's local (Sembast) most of the time, sequential is very fast.
      for (final product in products) {
        final currentStock = await stockController.getCurrentStock(product);
        if (currentStock <= product.minStockLevel) {
          lowStockCount++;
        }
      }

      final now = DateTime.now();
      int todayQuotationsCount = 0;
      int pendingQuotationsCount = 0;

      for (final q in quotations) {
        if (q.createdDate.year == now.year &&
            q.createdDate.month == now.month &&
            q.createdDate.day == now.day) {
          todayQuotationsCount++;
        }
        if (q.status == QuotationStatus.draft) {
          pendingQuotationsCount++;
        }
      }

      final sortedQuotations = List<Quotation>.from(quotations)
        ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
      
      final recent = sortedQuotations.take(3).toList();

      if (mounted) {
        setState(() {
          _totalProducts = products.length;
          _todaysQuotations = todayQuotationsCount;
          _pendingQuotations = pendingQuotationsCount;
          _lowStockItems = lowStockCount;
          _recentQuotations = recent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard data: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getGreeting() {"""

content = re.sub(r'class _DashboardScreenState extends State<DashboardScreen> \{.*?String _getGreeting\(\) \{', state_replacement, content, flags=re.DOTALL)


# Modify build method to show loader if loading
build_method_replacement = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ), // Sensible max width for web
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : CustomScrollView("""

content = re.sub(r'  @override\s*Widget build\(BuildContext context\) \{\s*return Scaffold\(\s*backgroundColor: AppColors\.background,\s*bottomNavigationBar: _buildBottomNav\(\),\s*body: SafeArea\(\s*child: Center\(\s*child: ConstrainedBox\(\s*constraints: const BoxConstraints\(\s*maxWidth: 800,\s*\), // Sensible max width for web\s*child: CustomScrollView\(', build_method_replacement, content)


# Modify empty state in recent quotations mapping
recent_list_replacement = """                      ...(_recentQuotations.isEmpty 
                          ? [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32.0),
                                child: Center(
                                  child: Text(
                                    'No quotations yet',
                                    style: TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            ]
                          : _recentQuotations.map((q) => _buildQuotationRow(q))),"""

content = re.sub(r'                      \.\.\._recentQuotations\.map\(\(q\) => _buildQuotationRow\(q\)\),', recent_list_replacement, content)


# Modify overview stats mapping
overview_replacement = """              children: [
                _buildStatCard('Total Products', _totalProducts.toString()),
                _buildStatCard('Today\\'s Quotations', _todaysQuotations.toString()),
                _buildStatCard('Pending Quotations', _pendingQuotations.toString()),
                _buildStatCard('Low Stock Items', _lowStockItems.toString()),
              ],"""
content = re.sub(r"              children: \[\s*_buildStatCard\('Total Products', '2,450'\),\s*_buildStatCard\('Today\\'s Quotations', '6'\),\s*_buildStatCard\('Pending Quotations', '12'\),\s*_buildStatCard\('Low Stock Items', '18'\),\s*\],", overview_replacement, content)


# Modify _buildQuotationRow
row_replacement = """  Widget _buildQuotationRow(Quotation quote) {
    Color statusBg;
    Color statusText;
    String statusLabel = quote.status.displayName;

    switch (quote.status) {
      case QuotationStatus.draft:
        statusBg = AppColors.statusPendingBg;
        statusText = AppColors.statusPendingText;
        break;
      case QuotationStatus.sent:
        statusBg = AppColors.statusSentBg;
        statusText = AppColors.statusSentText;
        break;
      case QuotationStatus.approved:
        statusBg = AppColors.statusApprovedBg;
        statusText = AppColors.statusApprovedText;
        break;
      default:
        statusBg = AppColors.statusPendingBg;
        statusText = AppColors.statusPendingText;
    }

    final formatter = NumberFormat('#,##0.00');
    final grandTotal = QuotationCalculator.calculateGrandTotal(
      QuotationCalculator.calculateSubtotal(quote.lineItems),
      quote.charges,
    );
    final formattedAmount = 'AED ${formatter.format(grandTotal)}';
    final formattedDate = DateFormat('dd MMM yyyy').format(quote.createdDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.customerInfo.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      quote.quotationNumber.isNotEmpty ? quote.quotationNumber : 'DRAFT',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '•',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }"""
content = re.sub(r'  Widget _buildQuotationRow\(QuotationSummary quote\) \{.*?\n  Widget _buildBottomNav\(\) \{', row_replacement + '\n\n  Widget _buildBottomNav() {', content, flags=re.DOTALL)

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
