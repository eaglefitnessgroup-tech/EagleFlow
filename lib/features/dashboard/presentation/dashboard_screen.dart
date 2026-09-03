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

  void _onBottomNavTapped(int index) {
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.of(context).pushNamed(AppRoutes.products);
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.previousQuotations);
        break;
      case 3:
        Navigator.of(context).pushNamed(AppRoutes.profile);
        break;
    }
  }

  void _showComingSoonSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(20.0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildSearchField(),
                            const SizedBox(height: 24),
                            _buildPrimaryActionCard(context),
                            if (ServiceLocator().authController.isAdmin) ...[
                              const SizedBox(height: 16),
                              _buildReservationActionCard(context),
                            ],
                            const SizedBox(height: 24),
                            _buildQuickActionsGrid(context),
                            const SizedBox(height: 32),
                            _buildOverviewSection(),
                            const SizedBox(height: 32),
                            _buildRecentQuotationsHeader(context),
                            const SizedBox(height: 16),
                            ...(_recentQuotations.isEmpty
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
                                : _recentQuotations.map((q) => _buildQuotationRow(q))),
                            const SizedBox(height: 24),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()},',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ServiceLocator().authController.currentUser?.name ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Welcome back.\nReady to create your next quotation?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.profile);
          },
          borderRadius: BorderRadius.circular(24),
          child: const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.person_outline,
              color: AppColors.primaryBlue,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search products or quotations',
          hintStyle: TextStyle(color: AppColors.mutedText),
          prefixIcon: Icon(Icons.search, color: AppColors.mutedText),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.createQuotation);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.request_quote_outlined,
                color: Colors.white,
                size: 32,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prepare and share a professional quotation',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationActionCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.itemReservation);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark_added_outlined,
                color: AppColors.primaryBlue,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Reservation',
                    style: TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reserve products for customers',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.mutedText, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        final children = [
          _buildActionCard(
            title: 'Products',
            icon: Icons.inventory_2_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
          ),
          _buildActionCard(
            title: 'Previous\nQuotations',
            icon: Icons.history_outlined,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.previousQuotations),
          ),
          _buildActionCard(
            title: 'Stock',
            icon: Icons.warehouse_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
          ),
          if (ServiceLocator().authController.isAdmin)
            _buildActionCard(
              title: 'Low Stock',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.amber.shade700,
              onTap: () =>
                  _showComingSoonSnackBar('Low Stock module coming soon.'),
            ),
          if (ServiceLocator().authController.canManageStock)
            _buildActionCard(
              title: 'Stock\nManagement',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.stockManagement),
            ),
          if (ServiceLocator().authController.canViewReports)
            _buildActionCard(
              title: 'Reports',
              icon: Icons.bar_chart_outlined,
              onTap: () => _showComingSoonSnackBar('Reports module coming soon.'),
            ),
          if (ServiceLocator().authController.canManageUsers)
            _buildActionCard(
              title: 'User\nManagement',
              icon: Icons.group_outlined,
              onTap: () => _showComingSoonSnackBar('User Management coming soon.'),
            ),
          if (ServiceLocator().authController.isAdmin)
            _buildActionCard(
              title: 'Settings',
              icon: Icons.settings_outlined,
              onTap: () => _showComingSoonSnackBar('Settings coming soon.'),
            ),
        ];

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += crossAxisCount) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < crossAxisCount; j++) {
            if (i + j < children.length) {
              rowChildren.add(Expanded(child: children[i + j]));
            } else {
              rowChildren.add(Expanded(child: const SizedBox()));
            }
            if (j < crossAxisCount - 1) {
              rowChildren.add(const SizedBox(width: 16));
            }
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowChildren,
              ),
            ),
          );
          if (i + crossAxisCount < children.length) {
            rows.add(const SizedBox(height: 16));
          }
        }

        return Column(children: rows);
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? AppColors.primaryBlue, size: 28),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard('Total Products', _totalProducts.toString()),
                _buildStatCard('Today\'s Quotations', _todaysQuotations.toString()),
                _buildStatCard('Pending Quotations', _pendingQuotations.toString()),
                if (ServiceLocator().authController.isAdmin)
                  _buildStatCard('Low Stock Items', _lowStockItems.toString()),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentQuotationsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Quotations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.previousQuotations);
          },
          child: const Text(
            'View All',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onBottomNavTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: AppColors.mutedText,
      showUnselectedLabels: true,
      elevation: 8,
      selectedIconTheme: const IconThemeData(size: 28),
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Products',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          label: 'Quotations',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}
