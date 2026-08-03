import 'package:flutter/material.dart';
import '../../app/routes/app_routes.dart';
import '../di/service_locator.dart';

class AdminGuard extends StatefulWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
  }

  void _checkAccess() {
    if (!mounted) return;

    final auth = ServiceLocator().authController;
    if (!auth.isAuthenticated) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      return;
    }

    if (!auth.isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin access required.')));
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ServiceLocator().authController;
    if (!auth.isAuthenticated || !auth.isAdmin) {
      return const Scaffold(backgroundColor: Colors.white);
    }
    return widget.child;
  }
}
