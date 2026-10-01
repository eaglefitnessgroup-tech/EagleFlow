import 'dart:async';

import 'package:eagleflow/app/theme/app_theme.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_product_mapping.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_result.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_rules.dart';
import 'package:eagleflow/features/quick_quote/presentation/quick_gym_quotation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_test_fixture.dart';

void main() {
  Widget screen(QuickQuoteFixture fixture, {bool initializeOnMount = false}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: QuickGymQuotationScreen(
        controller: fixture.controller,
        initializeOnMount: initializeOnMount,
      ),
    );
  }

  void pressGenerate(WidgetTester tester) {
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('generate-gym-button')),
    );
    button.onPressed!.call();
  }

  Future<void> generateWithPump(
    WidgetTester tester,
    QuickQuoteFixture fixture,
    String budget,
  ) async {
    await tester.enterText(
      find.byKey(const Key('target-budget-field')),
      budget,
    );
    pressGenerate(tester);
    await tester.pumpAndSettle();
    expect(fixture.controller.result, isNotNull);
  }

  testWidgets('shows initial loading without a false empty state', (
    tester,
  ) async {
    final completer = Completer<List<Product>>();
    final fixture = QuickQuoteFixture(productCompleter: completer);

    await tester.pumpWidget(screen(fixture, initializeOnMount: true));
    await tester.pump();

    expect(find.byKey(const Key('quick-quote-loading')), findsOneWidget);
    expect(find.text('Cardio Equipment'), findsNothing);

    completer.complete(fixture.products);
    await tester.pumpAndSettle();
    expect(find.text('Cardio Equipment'), findsOneWidget);
  });

  testWidgets('renders mapping failure with retry', (tester) async {
    final fixture = QuickQuoteFixture(
      refreshError: StateError('remote'),
      cachedError: StateError('cache'),
    );

    await tester.pumpWidget(screen(fixture, initializeOnMount: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-quote-fatal-error')), findsOneWidget);
    expect(find.textContaining('mappings are unavailable'), findsOneWidget);
    expect(find.byKey(const Key('quick-quote-retry')), findsOneWidget);
  });

  testWidgets('shows cached mapping fallback notice', (tester) async {
    final fixture = QuickQuoteFixture(refreshError: StateError('offline'));
    await fixture.initialize();

    await tester.pumpWidget(screen(fixture));

    expect(find.byKey(const Key('mapping-cache-notice')), findsOneWidget);
    expect(find.textContaining('cached mappings'), findsOneWidget);
  });

  testWidgets('budget field validates required and positive numeric values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));

    pressGenerate(tester);
    await tester.pump();
    expect(find.text('Target equipment budget is required.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('target-budget-field')), '0');
    pressGenerate(tester);
    await tester.pump();
    expect(find.text('Budget must be greater than zero.'), findsOneWidget);
  });

  testWidgets('Premier shows only approved pin and plate series', (
    tester,
  ) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));

    expect(find.text('Active Series (Pin) / APN'), findsOneWidget);
    expect(find.text('Torque Series (Pin) / PXN'), findsOneWidget);
    expect(find.text('Elite Series (Pin) / EPN'), findsOneWidget);
    expect(find.text('Active Series (PL) / APL'), findsOneWidget);
    expect(find.text('Torque Series (PL) / PXL'), findsOneWidget);
    expect(find.textContaining('TQN'), findsNothing);
    expect(find.textContaining('TQL'), findsNothing);
  });

  testWidgets('non-Premier hides Premier series controls', (tester) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    fixture.controller.selectStrengthBrand('Matrix');
    await tester.pumpWidget(screen(fixture));

    expect(find.text('Pin Loaded Series'), findsNothing);
    expect(find.text('Plate Loaded Series'), findsNothing);
    expect(find.textContaining('/ APN'), findsNothing);
    expect(find.textContaining('/ APL'), findsNothing);
  });

  testWidgets(
    'shows exactly five approved cardio roles and no excluded cardio',
    (tester) async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();
      await tester.pumpWidget(screen(fixture));

      for (final role in QuickQuoteCardioRole.values) {
        expect(find.byKey(Key('cardio-${role.name}-selector')), findsOneWidget);
      }
      expect(find.text('Rower Pro'), findsNothing);
      expect(find.text('Home Treadmill'), findsNothing);
      expect(find.textContaining('SkiErg'), findsNothing);
      expect(find.textContaining('Stair Master'), findsNothing);
    },
  );

  testWidgets('availability matrix and additional equipment render concisely', (
    tester,
  ) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));

    for (final area in QuickQuoteStrengthArea.values) {
      expect(find.byKey(ValueKey('availability-${area.name}')), findsOneWidget);
    }
    expect(find.text('Smith'), findsOneWidget);
    expect(find.text('Functional Trainer'), findsOneWidget);
    expect(find.text('Multi Station'), findsOneWidget);
    expect(find.text('Dumbbell full-set bundle'), findsOneWidget);
    expect(find.text('Weight plate complete family'), findsOneWidget);
  });

  testWidgets('Generate renders optimizer totals and under-target status', (
    tester,
  ) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));

    await tester.enterText(
      find.byKey(const Key('target-budget-field')),
      '100000',
    );
    pressGenerate(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-quote-result-summary')), findsOneWidget);
    expect(find.text('Target Budget'), findsOneWidget);
    expect(find.text('Equipment Subtotal'), findsOneWidget);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Generated Total'), findsOneWidget);
    expect(find.text('Difference from Target'), findsOneWidget);
    expect(find.text('Under target'), findsOneWidget);
    expect(
      fixture.controller.result!.status,
      QuickQuoteBudgetStatus.underTarget,
    );
  });

  testWidgets('renders over-target status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuickQuoteBudgetStatusBanner(
            status: QuickQuoteBudgetStatus.overTarget,
          ),
        ),
      ),
    );
    expect(find.text('Over target'), findsOneWidget);
  });

  testWidgets('renders exact status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuickQuoteBudgetStatusBanner(
            status: QuickQuoteBudgetStatus.exactTarget,
          ),
        ),
      ),
    );
    expect(find.text('Exact'), findsOneWidget);
  });

  testWidgets('insufficient budget shows minimum total and shortfall', (
    tester,
  ) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));
    await generateWithPump(tester, fixture, '1');

    expect(find.text('Insufficient budget'), findsOneWidget);
    expect(find.text('Minimum Balanced Total'), findsOneWidget);
    expect(find.text('Shortfall'), findsOneWidget);
  });

  testWidgets('selected equipment preview preserves optimizer order', (
    tester,
  ) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));
    await generateWithPump(tester, fixture, '100000');

    final table = tester.widget<DataTable>(find.byType(DataTable));
    final firstName = table.rows.first.cells.first.child as Text;
    expect(firstName.data, 'Commercial Treadmill');
    expect(find.byKey(const Key('selected-equipment-preview')), findsOneWidget);
    expect(find.text('Read-only preview in optimizer order.'), findsOneWidget);
  });

  testWidgets('mobile layout has no horizontal overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = QuickQuoteFixture();
    await fixture.initialize();

    await tester.pumpWidget(screen(fixture));
    await generateWithPump(tester, fixture, '100000');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final buttonRect = tester.getRect(
      find.byKey(const Key('generate-gym-button-box')),
    );
    expect(buttonRect.left, greaterThanOrEqualTo(0));
    expect(buttonRect.right, lessThanOrEqualTo(390));
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('screen exposes no quotation save, create, or handoff action', (
    tester,
  ) async {
    final fixture = QuickQuoteFixture();
    await fixture.initialize();
    await tester.pumpWidget(screen(fixture));

    expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
    expect(
      find.widgetWithText(ElevatedButton, 'Create Quotation'),
      findsNothing,
    );
    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsNothing);
  });
}
