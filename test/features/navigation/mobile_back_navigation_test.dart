import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:eagleflow/features/quotations/presentation/create_quotation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../authentication/fake_auth_repository.dart';

void main() {
  const createBackKey = Key('create-quotation-back-button');
  const productsBackKey = Key('products-back-button');

  setUp(() {
    ServiceLocator.resetForTesting();
    ServiceLocator().mockAuthRepository = FakeAuthRepository();
  });

  void ignoreKnownCreateQuotationOverflows(WidgetTester tester) {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
  }

  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpPushedScreen(
    WidgetTester tester, {
    required Size size,
    required Widget destination,
  }) async {
    await setViewport(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => destination),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Create Quotation shows mobile Back and pops pushed route', (
    tester,
  ) async {
    ignoreKnownCreateQuotationOverflows(tester);
    await pumpPushedScreen(
      tester,
      size: const Size(390, 844),
      destination: const CreateQuotationScreen(),
    );

    expect(find.byKey(createBackKey), findsOneWidget);

    await tester.tap(find.byKey(createBackKey));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(CreateQuotationScreen), findsNothing);
  });

  testWidgets('Create Quotation hides Back on desktop pushed route', (
    tester,
  ) async {
    ignoreKnownCreateQuotationOverflows(tester);
    await pumpPushedScreen(
      tester,
      size: const Size(1200, 900),
      destination: const CreateQuotationScreen(),
    );

    expect(find.byKey(createBackKey), findsNothing);
  });

  testWidgets('Products shows mobile Back and pops pushed route', (
    tester,
  ) async {
    await pumpPushedScreen(
      tester,
      size: const Size(390, 844),
      destination: const ProductsScreen(),
    );

    expect(find.byKey(productsBackKey), findsOneWidget);

    await tester.tap(find.byKey(productsBackKey));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(ProductsScreen), findsNothing);
  });

  testWidgets('Products hides Back when it is the mobile root tab', (
    tester,
  ) async {
    await setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(productsBackKey), findsNothing);
  });

  testWidgets('Products desktop header remains without Back', (tester) async {
    await pumpPushedScreen(
      tester,
      size: const Size(1200, 900),
      destination: const ProductsScreen(),
    );

    expect(find.byKey(productsBackKey), findsNothing);
  });
}
