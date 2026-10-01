import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/create_quotation_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/quotation_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../authentication/fake_auth_repository.dart';

void main() {
  const createBackKey = Key('create-quotation-back-button');
  const productsBackKey = Key('products-back-button');
  const quotationHeadingKey = Key('quotation-page-heading');
  const productsHeadingKey = Key('products-page-heading');

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

  Future<void> pumpDirectQuotationEditor(
    WidgetTester tester, {
    required Object arguments,
  }) async {
    ignoreKnownCreateQuotationOverflows(tester);
    await setViewport(tester, const Size(1200, 900));
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/create-quotation',
        onGenerateRoute: (_) => null,
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: '/create-quotation',
              arguments: arguments,
            ),
            builder: (_) => const CreateQuotationScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectIntegratedHeading({
    required Key headingKey,
    required Key backKey,
    required String title,
  }) {
    final heading = find.byKey(headingKey);
    expect(heading, findsOneWidget);
    expect(
      find.descendant(of: heading, matching: find.byKey(backKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heading, matching: find.text(title)),
      findsWidgets,
    );
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
    expectIntegratedHeading(
      headingKey: quotationHeadingKey,
      backKey: createBackKey,
      title: 'New Quotation',
    );

    await tester.tap(find.byKey(createBackKey));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(CreateQuotationScreen), findsNothing);
  });

  testWidgets('Create Quotation integrates Back on desktop pushed route', (
    tester,
  ) async {
    ignoreKnownCreateQuotationOverflows(tester);
    await pumpPushedScreen(
      tester,
      size: const Size(1200, 900),
      destination: const CreateQuotationScreen(),
    );

    expectIntegratedHeading(
      headingKey: quotationHeadingKey,
      backKey: createBackKey,
      title: 'New Quotation',
    );
  });

  testWidgets(
    'direct Create Quotation Back falls back to Previous Quotations',
    (tester) async {
      ignoreKnownCreateQuotationOverflows(tester);
      await setViewport(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: const CreateQuotationScreen(),
          routes: {
            '/previous-quotations': (_) =>
                const Scaffold(body: Text('Previous Quotations fallback')),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(createBackKey));
      await tester.pumpAndSettle();

      expect(find.text('Previous Quotations fallback'), findsOneWidget);
      expect(find.byType(CreateQuotationScreen), findsNothing);
    },
  );

  testWidgets('Products shows mobile Back and pops pushed route', (
    tester,
  ) async {
    await pumpPushedScreen(
      tester,
      size: const Size(390, 844),
      destination: const ProductsScreen(),
    );

    expect(find.byKey(productsBackKey), findsOneWidget);
    expectIntegratedHeading(
      headingKey: productsHeadingKey,
      backKey: productsBackKey,
      title: 'Products',
    );

    await tester.tap(find.byKey(productsBackKey));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(ProductsScreen), findsNothing);
  });

  testWidgets('direct Products Back falls back to Dashboard', (tester) async {
    await setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: const ProductsScreen(),
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('Dashboard fallback')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expectIntegratedHeading(
      headingKey: productsHeadingKey,
      backKey: productsBackKey,
      title: 'Products',
    );

    await tester.tap(find.byKey(productsBackKey));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard fallback'), findsOneWidget);
    expect(find.byType(ProductsScreen), findsNothing);
  });

  testWidgets('Products desktop header integrates Back with title', (
    tester,
  ) async {
    await pumpPushedScreen(
      tester,
      size: const Size(1200, 900),
      destination: const ProductsScreen(),
    );

    expectIntegratedHeading(
      headingKey: productsHeadingKey,
      backKey: productsBackKey,
      title: 'Products',
    );
  });

  testWidgets('quotation heading labels new, edit, and revise modes', (
    tester,
  ) async {
    Future<void> pumpHeader({bool isEditing = false, bool isRevision = false}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotationPageHeader(
              quotationNumber: 'QT-TEST-001',
              isEditing: isEditing,
              isRevision: isRevision,
              showBack: true,
              onBack: () {},
            ),
          ),
        ),
      );
    }

    await pumpHeader();
    expect(find.text('New Quotation'), findsWidgets);

    await pumpHeader(isEditing: true);
    expect(find.text('Edit Quotation'), findsWidgets);
    expect(find.text('New Quotation'), findsNothing);

    await pumpHeader(isRevision: true);
    expect(find.text('Revise Quotation'), findsWidgets);
    expect(find.text('Edit Quotation'), findsNothing);
  });

  testWidgets('persisted quotation opens with integrated Edit heading', (
    tester,
  ) async {
    final quotation = QuotationDefaults.createEmptyDraft().copyWith(
      id: 'saved-original',
      quotationNumber: 'QT-EDIT-001',
    );
    await pumpDirectQuotationEditor(tester, arguments: quotation);

    expectIntegratedHeading(
      headingKey: quotationHeadingKey,
      backKey: createBackKey,
      title: 'Edit Quotation',
    );
    expect(find.text('QT-EDIT-001'), findsWidgets);
  });

  testWidgets('revision controller opens with integrated Revise heading', (
    tester,
  ) async {
    final source = QuotationDefaults.createEmptyDraft().copyWith(
      id: 'saved-source',
      quotationNumber: 'QT-REV-001',
    );
    await pumpDirectQuotationEditor(
      tester,
      arguments: QuotationController.forRevision(source),
    );

    expectIntegratedHeading(
      headingKey: quotationHeadingKey,
      backKey: createBackKey,
      title: 'Revise Quotation',
    );
    expect(find.text('QT-REV-001 / R1'), findsWidgets);
  });
}
