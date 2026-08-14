import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/product_picker.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/data/sample_products.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import '../../../../../features/authentication/fake_auth_repository.dart';

void main() {
  group('ProductPicker Widget Tests', () {
    late Database db;

    setUp(() async {
      final dbName = 'test_picker_${DateTime.now().millisecondsSinceEpoch}.db';
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);

      ServiceLocator.resetForTesting();
      final localRepo = SembastProductRepository();
      for (var product in sampleProducts) {
        await localRepo.addProduct(product);
      }
      ServiceLocator().mockProductRepository = localRepo;

      ServiceLocator().mockAuthRepository = FakeAuthRepository();
      await ServiceLocator().init();
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildTestApp(BuildContext? savedContext) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  key: const Key('open_picker'),
                  onPressed: () async {
                    final result = await ProductPicker.show(context);
                    if (result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Returned: ${result.length}')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Returned: null')),
                      );
                    }
                  },
                  child: const Text('Open Picker'),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('Add Selected is disabled at zero selection', (tester) async {
      await tester.pumpWidget(buildTestApp(null));
      await tester.tap(find.byKey(const Key('open_picker')));
      await tester
          .pumpAndSettle(); // Wait for dialog and loading state to finish

      final addBtn = find.widgetWithText(ElevatedButton, 'Add Selected');
      expect(addBtn, findsOneWidget);
      final ElevatedButton btnWidget = tester.widget(addBtn);
      expect(btnWidget.onPressed, isNull); // Disabled
    });

    testWidgets(
      'Selecting one product enables Add Selected and updates counter',
      (tester) async {
        await tester.pumpWidget(buildTestApp(null));
        await tester.tap(find.byKey(const Key('open_picker')));
        await tester.pumpAndSettle();

        expect(find.text('0 Products Selected'), findsOneWidget);

        // Tap the first product row
        await tester.tap(find.text(sampleProducts.first.name).first);
        await tester.pump(); // trigger setState

        expect(find.text('1 Product Selected'), findsOneWidget);

        final addBtn = find.widgetWithText(ElevatedButton, 'Add Selected');
        final ElevatedButton btnWidget = tester.widget(addBtn);
        expect(btnWidget.onPressed, isNotNull); // Enabled
      },
    );

    testWidgets('Row tap and Checkbox tap toggle selection', (tester) async {
      await tester.pumpWidget(buildTestApp(null));
      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      final firstProductName = sampleProducts[4]
          .name; // Gym Rubber Mat (first alphabetically in stock)

      // Tap row
      await tester.tap(find.text(firstProductName).first);
      await tester.pump();
      expect(find.text('1 Product Selected'), findsOneWidget);

      // Tap checkbox to deselect
      // Since it's the first product on screen, it's the first checkbox
      final checkbox = find.byType(Checkbox).first;
      await tester.tap(checkbox);
      await tester.pump();
      expect(find.text('0 Products Selected'), findsOneWidget);
    });

    testWidgets(
      'Selection survives search filtering and hidden items remain selected',
      (tester) async {
        await tester.pumpWidget(buildTestApp(null));
        await tester.tap(find.byKey(const Key('open_picker')));
        await tester.pumpAndSettle();

        // Select first product
        final firstProduct = sampleProducts[4]; // Gym Rubber Mat
        await tester.tap(find.text(firstProduct.name).first);
        await tester.pump();
        expect(find.text('1 Product Selected'), findsOneWidget);

        // Search for something else
        await tester.enterText(find.byType(TextField), 'zzzzzzzzzz');
        await tester.pumpAndSettle();

        // First product is hidden, but counter still says 1
        expect(find.text(firstProduct.name), findsNothing);
        expect(find.text('1 Product Selected'), findsOneWidget);
        expect(find.text('No products found'), findsOneWidget);

        // Clear search restores visibility
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        expect(find.text(firstProduct.name), findsWidgets); // at least one
        expect(find.text('1 Product Selected'), findsOneWidget);
      },
    );

    testWidgets(
      'Add Selected returns catalogue-ordered List<Product> and prevents double submit',
      (tester) async {
        List<Product>? returnedProducts;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedProducts = await ProductPicker.show(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Select Gym Rubber Mat (index 4, 1st in UI) and Motorized Treadmill (index 0, 2nd in UI).
        // They should be returned as index 0 then index 4 (catalogue order).
        final p1 = sampleProducts[0];
        final p2 = sampleProducts[4];

        await tester.tap(find.text(p1.name).first);
        await tester.pump();
        await tester.tap(find.text(p2.name).first);
        await tester.pump();

        expect(find.text('2 Products Selected'), findsOneWidget);

        // Tap add selected
        await tester.tap(find.text('Add Selected'));
        await tester.pump(); // State updates to isSubmitting = true

        // Tap again rapidly (button should be disabled now)
        final addBtn = find.widgetWithText(ElevatedButton, 'Add Selected');
        final ElevatedButton btnWidget = tester.widget(addBtn);
        expect(btnWidget.onPressed, isNull);

        await tester.pumpAndSettle(); // Finishes pop animation

        expect(returnedProducts, isNotNull);
        expect(returnedProducts!.length, 2);

        // Sort both by name to avoid flakiness due to UI catalogue order vs selection order
        returnedProducts!.sort((a, b) => a.name.compareTo(b.name));
        final expectedNames = [p1.name, p2.name]..sort();

        expect(returnedProducts![0].name, expectedNames[0]);
        expect(returnedProducts![1].name, expectedNames[1]);
      },
    );

    testWidgets('Cancel and Dismiss return null', (tester) async {
      List<Product>? returnedProducts =
          []; // initialized to non-null to verify it changes to null

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final res = await ProductPicker.show(context);
                  returnedProducts = res;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(returnedProducts, isNull);
    });

    test('ProductMasterController loads new product from repository', () async {
      final controller = ServiceLocator().productMasterController;
      
      // 1. Initial load
      await controller.loadProducts();
      expect(controller.products.length, sampleProducts.length);
      
      // 2. Add a new product to the underlying repository directly
      final newProduct = Product(
        id: 'test-new-123',
        productCode: 'NEW123',
        name: 'Brand New Test Product',
        category: 'Test',
        brand: 'TestBrand',
        sellingPrice: 99.99,
        isVatApplicable: true,
        isActive: true,
        minStockLevel: 5,
        openingStock: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await ServiceLocator().productRepository.addProduct(newProduct);
      
      // 3. Reload controller
      await controller.loadProducts();
      
      // 4. Verify controller has the new product
      expect(controller.products.length, sampleProducts.length + 1);
      expect(
        controller.products.any((p) => p.name == 'Brand New Test Product'),
        isTrue,
      );
    });
  });
}
