import 'package:flutter/material.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/di/service_locator.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2200));

    if (mounted) {
      final authController = ServiceLocator().authController;

      // If initialization is somehow still happening (e.g. late init), wait for it
      while (authController.isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;

      if (authController.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduced-motion settings where practical
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative Wave
            Positioned.fill(child: CustomPaint(painter: _WavePainter())),

            // Main Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: disableAnimations
                    ? _buildContent(context)
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildContent(context),
                        ),
                      ),
              ),
            ),

            // Bottom Version Text
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'v1.0.0\nEagleFlow',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.flight_takeoff,
          size: 72,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(height: 24),
        Text(
          'EagleFlow',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Quotation & Product Management',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: AppColors.mutedText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Preparing your workspace...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    final path2 = Path();
    final path3 = Path();

    final centerY = size.height * 0.55;

    path1.moveTo(0, centerY);
    path2.moveTo(0, centerY + 20);
    path3.moveTo(0, centerY - 20);

    for (double i = 0; i <= size.width; i++) {
      final dx = i;
      final dy1 = centerY + math.sin((i / size.width) * 2 * math.pi) * 30;
      final dy2 =
          centerY + 20 + math.sin(((i + 50) / size.width) * 2 * math.pi) * 40;
      final dy3 =
          centerY - 20 + math.sin(((i - 50) / size.width) * 2 * math.pi) * 25;

      path1.lineTo(dx, dy1);
      path2.lineTo(dx, dy2);
      path3.lineTo(dx, dy3);
    }

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
