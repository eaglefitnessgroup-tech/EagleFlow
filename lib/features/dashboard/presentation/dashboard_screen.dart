import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../quotations/domain/quotation.dart';
import '../../quotations/domain/quotation_status.dart';
import '../../quotations/application/quotation_calculator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalProducts = 0;
  int _todaysQuotations = 0;
  int _pendingQuotations = 0;
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

      final products = await productRepo.getAllProducts();
      final quotations = await quotationRepo.getAllQuotations();

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
      
      final recent = sortedQuotations.take(5).toList();

      if (mounted) {
        setState(() {
          _totalProducts = products.length;
          _todaysQuotations = todayQuotationsCount;
          _pendingQuotations = pendingQuotationsCount;
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
          SnackBar(
            content: Text('Failed to load dashboard data: $e'),
            backgroundColor: AppColors.statusRejectedText,
          ),
        );
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Welcome Back';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebar(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    )
                  : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rocket_launch, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'EagleFlow',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSidebarItem(
            context,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: null,
            isSelected: true,
          ),
          _buildSidebarItem(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            route: AppRoutes.products,
            isSelected: false,
          ),
          _buildSidebarItem(
            context,
            icon: Icons.history_outlined,
            label: 'Quotations',
            route: AppRoutes.previousQuotations,
            isSelected: false,
          ),
          if (ServiceLocator().authController.canManageStock)
            _buildSidebarItem(
              context,
              icon: Icons.admin_panel_settings_outlined,
              label: 'Stock Management',
              route: AppRoutes.stockManagement,
              isSelected: false,
            ),
          const Spacer(),
          _buildSidebarItem(
            context,
            icon: Icons.person_outline,
            label: 'Profile',
            route: AppRoutes.profile,
            isSelected: false,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? route,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: route != null ? () => Navigator.of(context).pushNamed(route) : null,
        hoverColor: AppColors.primarySoft.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                width: 4,
              ),
            ),
            color: isSelected ? AppColors.primarySoft.withValues(alpha: 0.3) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryBlue : AppColors.mutedText, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryBlue : AppColors.mutedText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildTopBar(),
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildOverviewSection(),
                  const SizedBox(height: 24),
                  _buildPrimaryActionCard(context),
                  const SizedBox(height: 24),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 24),
                  _buildRecentQuotationsSection(context),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              alignment: Alignment.centerLeft,
              child: _buildSearchField(),
            ),
          ),
          const SizedBox(width: 24),
          InkWell(
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
            borderRadius: BorderRadius.circular(18),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySoft,
              child: Icon(
                Icons.person_outline,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()}, ${ServiceLocator().authController.currentUser?.name ?? 'User'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here is your overview for today.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontSize: 15,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: AppColors.mutedText, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: AppColors.mutedText, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Products', _totalProducts.toString(), Icons.inventory_2_outlined)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard('Today\'s Quotations', _todaysQuotations.toString(), Icons.today_outlined)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard('Pending Quotations', _pendingQuotations.toString(), Icons.pending_actions_outlined)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: AppColors.primaryBlue.withValues(alpha: 0.5), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.createQuotation);
        },
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primaryBlue.withValues(alpha: 0.9),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.request_quote_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Quotation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prepare and share a professional quotation.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Create Now',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: AppColors.primaryBlue, size: 16),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickActionsGrid(BuildContext context) {
    final children = [
      _buildActionCard(
        title: 'Products',
        icon: Icons.inventory_2_outlined,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
      ),
      _buildActionCard(
        title: 'Previous Quotations',
        icon: Icons.history_outlined,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.previousQuotations),
      ),
      _buildActionCard(
        title: 'Stock',
        icon: Icons.warehouse_outlined,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
      ),
      if (ServiceLocator().authController.canManageStock)
        _buildActionCard(
          title: 'Stock Management',
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.stockManagement),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.charcoal,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: children.map((child) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: child == children.last ? 0 : 16.0),
              child: child,
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.surface.withValues(alpha: 0.8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 20),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentQuotationsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recent Quotations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.previousQuotations);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recentQuotations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Text(
              'No quotations yet',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          ..._recentQuotations.map((q) => _buildQuotationRow(q)),
      ],
    );
  }

  Widget _buildQuotationRow(Quotation quote) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.surface.withValues(alpha: 0.8),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.customerInfo.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote.quotationNumber.isNotEmpty ? quote.quotationNumber : 'DRAFT',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formattedAmount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 90,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
