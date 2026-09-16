import 'package:eagleflow/features/area_estimator/presentation/area_estimator_screen.dart';
import 'package:eagleflow/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AreaEstimatorScreen(),
    );
  }

  Future<void> selectUnit(
    WidgetTester tester,
    Key dropdownKey,
    String unit,
  ) async {
    await tester.tap(find.byKey(dropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(unit).last);
    await tester.pumpAndSettle();
  }

  Future<void> calculate(
    WidgetTester tester, {
    required String length,
    required String width,
    required String matLength,
    required String matWidth,
    String areaUnit = 'm',
    String matUnit = 'm',
  }) async {
    await tester.enterText(find.byKey(const Key('length-field')), length);
    await tester.enterText(find.byKey(const Key('width-field')), width);
    await tester.enterText(
      find.byKey(const Key('mat-length-field')),
      matLength,
    );
    await tester.enterText(find.byKey(const Key('mat-width-field')), matWidth);

    if (areaUnit != 'm') {
      await selectUnit(tester, const Key('area-unit-dropdown'), areaUnit);
    }
    if (matUnit != 'm') {
      await selectUnit(tester, const Key('mat-unit-dropdown'), matUnit);
    }

    await tester.tap(find.byKey(const Key('calculate-button')));
    await tester.pump();
  }

  String resultText(WidgetTester tester, Key key) {
    return tester.widget<Text>(find.byKey(key)).data!;
  }

  void expectResults(
    WidgetTester tester, {
    required String areaSqm,
    required String areaSqft,
    required String requiredMats,
  }) {
    expect(resultText(tester, const Key('area-sqm-result')), areaSqm);
    expect(resultText(tester, const Key('area-sqft-result')), areaSqft);
    expect(resultText(tester, const Key('required-mats-result')), requiredMats);
  }

  testWidgets('renders the requested inputs, action, and empty results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen());

    expect(find.widgetWithText(TextFormField, 'Length'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Width'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mat Length'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mat Width'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Mat Unit'), findsOneWidget);
    expect(find.text('Calculate'), findsOneWidget);
    expect(find.text('Area (SQM)'), findsOneWidget);
    expect(find.text('Area (SQFT)'), findsOneWidget);
    expect(find.text('Required Mats'), findsOneWidget);
    expect(resultText(tester, const Key('area-sqm-result')), '—');
    expect(resultText(tester, const Key('area-sqft-result')), '—');
    expect(resultText(tester, const Key('required-mats-result')), '—');
  });

  testWidgets('fits cleanly at supported responsive widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const widths = [360.0, 390.0, 430.0, 768.0, 1024.0];
    const horizontallyBoundedKeys = [
      Key('length-field'),
      Key('width-field'),
      Key('area-unit-dropdown'),
      Key('mat-length-field'),
      Key('mat-width-field'),
      Key('mat-unit-dropdown'),
      Key('calculate-button'),
      Key('area-sqm-result'),
      Key('area-sqft-result'),
      Key('required-mats-result'),
    ];

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'overflow at ${width}px');

      for (final key in horizontallyBoundedKeys) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$key at ${width}px');
        expect(
          rect.right,
          lessThanOrEqualTo(width),
          reason: '$key at ${width}px',
        );
      }

      expect(
        tester.getSize(find.byKey(const Key('calculate-button'))).height,
        greaterThanOrEqualTo(48),
        reason: 'Calculate touch target at ${width}px',
      );
    }
  });

  testWidgets('calculates meter values', (tester) async {
    await tester.pumpWidget(buildScreen());

    await calculate(
      tester,
      length: '2',
      width: '3',
      matLength: '1',
      matWidth: '1',
    );

    expectResults(
      tester,
      areaSqm: '6.00',
      areaSqft: '64.58',
      requiredMats: '6',
    );
  });

  testWidgets('converts centimeter values', (tester) async {
    await tester.pumpWidget(buildScreen());

    await calculate(
      tester,
      length: '200',
      width: '300',
      matLength: '100',
      matWidth: '100',
      areaUnit: 'cm',
      matUnit: 'cm',
    );

    expectResults(
      tester,
      areaSqm: '6.00',
      areaSqft: '64.58',
      requiredMats: '6',
    );
  });

  testWidgets('converts feet values', (tester) async {
    await tester.pumpWidget(buildScreen());

    await calculate(
      tester,
      length: '10',
      width: '10',
      matLength: '2',
      matWidth: '2',
      areaUnit: 'ft',
      matUnit: 'ft',
    );

    expectResults(
      tester,
      areaSqm: '9.29',
      areaSqft: '100.00',
      requiredMats: '25',
    );
  });

  testWidgets('converts inch values', (tester) async {
    await tester.pumpWidget(buildScreen());

    await calculate(
      tester,
      length: '120',
      width: '120',
      matLength: '24',
      matWidth: '24',
      areaUnit: 'in',
      matUnit: 'in',
    );

    expectResults(
      tester,
      areaSqm: '9.29',
      areaSqft: '100.00',
      requiredMats: '25',
    );
  });

  testWidgets('supports mixed floor and mat units', (tester) async {
    await tester.pumpWidget(buildScreen());

    await calculate(
      tester,
      length: '2',
      width: '3',
      matLength: '100',
      matWidth: '50',
      matUnit: 'cm',
    );

    expectResults(
      tester,
      areaSqm: '6.00',
      areaSqft: '64.58',
      requiredMats: '12',
    );
  });

  testWidgets('rounds required mats up', (tester) async {
    await tester.pumpWidget(buildScreen());

    await calculate(
      tester,
      length: '2',
      width: '2',
      matLength: '1.5',
      matWidth: '1',
    );

    expectResults(
      tester,
      areaSqm: '4.00',
      areaSqft: '43.06',
      requiredMats: '3',
    );
  });

  final invalidCases = [
    (name: 'empty values', length: '', message: 'Please complete all fields.'),
    (
      name: 'non-numeric values',
      length: 'not-a-number',
      message: 'Please enter valid numbers.',
    ),
    (
      name: 'zero values',
      length: '0',
      message: 'Values must be greater than zero.',
    ),
    (
      name: 'negative values',
      length: '-1',
      message: 'Values must be greater than zero.',
    ),
    (
      name: 'non-finite values',
      length: 'Infinity',
      message: 'Please enter valid numbers.',
    ),
  ];

  for (final invalidCase in invalidCases) {
    testWidgets('rejects ${invalidCase.name}', (tester) async {
      await tester.pumpWidget(buildScreen());

      await calculate(
        tester,
        length: invalidCase.length,
        width: '2',
        matLength: '1',
        matWidth: '1',
      );

      expect(find.text(invalidCase.message), findsOneWidget);
      expect(resultText(tester, const Key('area-sqm-result')), '—');
      expect(resultText(tester, const Key('area-sqft-result')), '—');
      expect(resultText(tester, const Key('required-mats-result')), '—');
    });
  }
}
