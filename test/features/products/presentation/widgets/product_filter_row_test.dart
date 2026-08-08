import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/products/presentation/widgets/product_filter_row.dart';

void main() {
  group('ProductFilterRow Responsive Layout Tests', () {
    testWidgets('Does not overflow on narrow mobile screen (360px)', (WidgetTester tester) async {
      // Set narrow physical size (360x800) to replicate typical narrow mobile device
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool inStockToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Ensure Scaffold adds standard padding
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ProductFilterRow(
                inStockOnly: false,
                lowStockOnly: false,
                onInStockToggled: (val) => inStockToggled = val,
                onLowStockToggled: (val) {},
              ),
            ),
          ),
        ),
      );

      // Verify that Flutter doesn't throw a RenderFlex overflow exception
      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Layout should not overflow at 360px width');

      // Verify widgets rendered correctly
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);

      // Verify interaction
      await tester.tap(find.text('In Stock'));
      await tester.pump();
      expect(inStockToggled, true);
    });
  });
}
