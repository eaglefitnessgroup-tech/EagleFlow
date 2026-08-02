import 'package:flutter/material.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';

class StockManagementScreen extends StatelessWidget {
  const StockManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Stock Management',
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
          children: [
            _buildActionCard(
              context,
              title: 'Stock In',
              subtitle: 'Add new stock to inventory',
              icon: Icons.add_circle_outline,
              iconColor: AppColors.statusApprovedText,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.stockIn);
              },
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: 'Stock Out',
              subtitle: 'Deduct stock from inventory',
              icon: Icons.remove_circle_outline,
              iconColor: AppColors.statusRejectedText,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.stockOut);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        debugPrint('Tapped $title action card');
        onTap();
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
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.mutedText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
