import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class EagleBottomNav extends StatelessWidget {
  final int currentIndex;

  const EagleBottomNav({super.key, required this.currentIndex});

  void _onBottomNavTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed(AppRoutes.products);
        break;
      case 2:
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.previousQuotations);
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onBottomNavTapped(context, index),
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
