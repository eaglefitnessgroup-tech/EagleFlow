import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../features/authentication/application/auth_controller.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class EagleFlowApp extends StatelessWidget {
  const EagleFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = ServiceLocator().authController;

    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (authController.bootstrapState == AuthBootstrapState.initializing ||
            authController.bootstrapState ==
                AuthBootstrapState.authenticatedDataLoading) {
          return const _AuthBootstrapApp();
        }

        if (authController.bootstrapState == AuthBootstrapState.failed) {
          return const _WorkspaceBootstrapFailureApp();
        }

        return _ResolvedEagleFlowApp(
          isAuthenticated: authController.isAuthenticated,
        );
      },
    );
  }
}

class _WorkspaceBootstrapFailureApp extends StatelessWidget {
  const _WorkspaceBootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EagleFlow',
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(child: Text('Unable to load workspace.')),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AuthBootstrapApp extends StatelessWidget {
  const _AuthBootstrapApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EagleFlow',
      theme: AppTheme.lightTheme,
      routes: {AppRoutes.splash: (context) => const SplashScreen()},
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.splash),
          builder: (context) => const SplashScreen(),
        ),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

class _ResolvedEagleFlowApp extends StatelessWidget {
  final bool isAuthenticated;

  const _ResolvedEagleFlowApp({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EagleFlow',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      onGenerateInitialRoutes: _generateInitialRoutes,
      debugShowCheckedModeBanner: false,
    );
  }

  List<Route<dynamic>> _generateInitialRoutes(String requestedRoute) {
    var targetRoute = requestedRoute;

    if (!isAuthenticated) {
      targetRoute = AppRoutes.login;
    } else if (targetRoute == AppRoutes.splash) {
      targetRoute = AppRoutes.dashboard;
    }

    final routes = AppRoutes.routes;
    final routeBuilder = routes[targetRoute] ?? routes[AppRoutes.dashboard]!;

    return [
      MaterialPageRoute<void>(
        settings: RouteSettings(name: targetRoute),
        builder: routeBuilder,
      ),
    ];
  }
}
