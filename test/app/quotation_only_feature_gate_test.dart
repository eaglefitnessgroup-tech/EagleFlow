import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/config/app_features.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory is disabled for the quotation-only release', () {
    expect(AppFeatures.inventoryEnabled, isFalse);
  });

  testWidgets('inventory routes resolve to the dashboard while disabled', (
    tester,
  ) async {
    final builtRoutes = <String, Widget>{};
    const inventoryRoutes = <String>[
      AppRoutes.stockManagement,
      AppRoutes.stockIn,
      AppRoutes.stockOut,
      AppRoutes.stockOutByQuotation,
      AppRoutes.itemReservation,
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            for (final route in inventoryRoutes) {
              builtRoutes[route] = AppRoutes.routes[route]!(context);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(builtRoutes.keys, containsAll(inventoryRoutes));
    expect(builtRoutes.values, everyElement(isA<DashboardScreen>()));
  });
}
