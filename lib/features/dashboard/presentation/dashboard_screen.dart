import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildNavCard(
                context,
                title: 'Products',
                icon: Icons.inventory_2_outlined,
                route: AppRoutes.products,
              ),
              _buildNavCard(
                context,
                title: 'Create Quotation',
                icon: Icons.request_quote_outlined,
                route: AppRoutes.createQuotation,
              ),
              _buildNavCard(
                context,
                title: 'Previous Quotations',
                icon: Icons.history_outlined,
                route: AppRoutes.previousQuotations,
              ),
              _buildNavCard(
                context,
                title: 'Profile',
                icon: Icons.person_outline,
                route: AppRoutes.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
  }) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
