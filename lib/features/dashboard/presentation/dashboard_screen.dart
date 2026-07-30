import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';

// Temporary structured models
class QuotationSummary {
  final String id;
  final String customer;
  final String amount;
  final String date;
  final QuotationStatus status;

  const QuotationSummary({
    required this.id,
    required this.customer,
    required this.amount,
    required this.date,
    required this.status,
  });
}

enum QuotationStatus { pending, sent, approved }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String _staffName = "Anshad";
  final int _currentIndex = 0;

  final List<QuotationSummary> _recentQuotations = const [
    QuotationSummary(
      id: 'QT-1025',
      customer: 'Falcon Gym',
      amount: 'AED 14,500',
      date: 'Today',
      status: QuotationStatus.pending,
    ),
    QuotationSummary(
      id: 'QT-1024',
      customer: 'Power Fitness',
      amount: 'AED 7,800',
      date: 'Yesterday',
      status: QuotationStatus.sent,
    ),
    QuotationSummary(
      id: 'QT-1023',
      customer: 'Al Noor Club',
      amount: 'AED 2,950',
      date: '28 Jul 2026',
      status: QuotationStatus.approved,
    ),
  ];

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
        // Already on home
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
            ), // Sensible max width for web
            child: CustomScrollView(
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
                      const SizedBox(height: 24),
                      _buildQuickActionsGrid(context),
                      const SizedBox(height: 32),
                      _buildOverviewSection(),
                      const SizedBox(height: 32),
                      _buildRecentQuotationsHeader(context),
                      const SizedBox(height: 16),
                      ..._recentQuotations.map((q) => _buildQuotationRow(q)),
                      const SizedBox(height: 24), // Extra bottom padding
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
                _staffName,
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

  Widget _buildQuickActionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.15,
          children: [
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
              onTap: () => _showComingSoonSnackBar('Stock module coming soon.'),
            ),
            _buildActionCard(
              title: 'Low Stock',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.amber.shade700,
              onTap: () =>
                  _showComingSoonSnackBar('Low Stock module coming soon.'),
            ),
          ],
        );
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? AppColors.primaryBlue, size: 28),
            const Spacer(),
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                _buildStatCard('Total Products', '2,450'),
                _buildStatCard('Today\'s Quotations', '6'),
                _buildStatCard('Pending Quotations', '12'),
                _buildStatCard('Low Stock Items', '18'),
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildQuotationRow(QuotationSummary quote) {
    Color statusBg;
    Color statusText;
    String statusLabel;

    switch (quote.status) {
      case QuotationStatus.pending:
        statusBg = AppColors.statusPendingBg;
        statusText = AppColors.statusPendingText;
        statusLabel = 'Pending';
        break;
      case QuotationStatus.sent:
        statusBg = AppColors.statusSentBg;
        statusText = AppColors.statusSentText;
        statusLabel = 'Sent';
        break;
      case QuotationStatus.approved:
        statusBg = AppColors.statusApprovedBg;
        statusText = AppColors.statusApprovedText;
        statusLabel = 'Approved';
        break;
    }

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
                  quote.customer,
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
                      quote.id,
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
                      quote.date,
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
                quote.amount,
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
