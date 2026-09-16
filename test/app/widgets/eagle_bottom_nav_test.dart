import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/app/widgets/eagle_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp({required int currentIndex}) {
    return MaterialApp(
      routes: {
        AppRoutes.dashboard: (_) => const Scaffold(body: Text('Dashboard')),
        AppRoutes.products: (_) => const Scaffold(body: Text('Products')),
        AppRoutes.previousQuotations: (_) =>
            const Scaffold(body: Text('Quotations')),
        AppRoutes.areaEstimator: (_) =>
            const Scaffold(body: Text('Area Estimator Screen')),
      },
      home: Scaffold(
        body: const Text('Current Screen'),
        bottomNavigationBar: EagleBottomNav(currentIndex: currentIndex),
      ),
    );
  }

  testWidgets('shows only the four requested mobile destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(currentIndex: 0));

    expect(find.text('Area Estimator'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    expect(find.text('Profile'), findsNothing);

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.items, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens Area Estimator from the mobile navigation', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(currentIndex: 0));

    await tester.tap(find.text('Area Estimator'));
    await tester.pumpAndSettle();

    expect(find.text('Area Estimator Screen'), findsOneWidget);
  });

  testWidgets('highlights Area Estimator at index 3', (tester) async {
    await tester.pumpWidget(buildApp(currentIndex: 3));

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(navigation.currentIndex, 3);
    expect(navigation.items[3].label, 'Area Estimator');
  });
}
