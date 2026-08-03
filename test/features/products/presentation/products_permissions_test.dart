import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:eagleflow/features/products/presentation/product_details_screen.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/presentation/widgets/product_card.dart';

void main() {
  final dummyProduct = Product(
    id: 'test-product',
    name: 'Test Product',
    productCode: 'TP-01',
    brand: 'Eagle',
    category: 'Equipment',
    sellingPrice: 100.0,
    openingStock: 10,
    minStockLevel: 5,
    description: 'Test description',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    ServiceLocator.resetForTesting();

    final dbName =
        'test_products_perms_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    await ServiceLocator().init();
    await ServiceLocator().authController.logout();

    await ServiceLocator().productMasterController.addProduct(dummyProduct);
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  Widget buildProductsScreen() {
    return const MaterialApp(home: ProductsScreen());
  }

  Widget buildProductDetailsScreen() {
    return MaterialApp(home: ProductDetailsScreen(testProduct: dummyProduct));
  }

  group('Products Screen Permissions', () {
    testWidgets('Admin sees Add Product', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await ServiceLocator().authController.login(
          username: 'admin',
          password: 'admin123',
          rememberMe: true,
        );
      });

      await tester.pumpWidget(buildProductsScreen());
      await tester.pumpAndSettle();

      expect(find.text('+ Add Product'), findsOneWidget);
    });

    testWidgets('Salesperson does not see Add Product', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await ServiceLocator().authController.login(
          username: 'sales',
          password: 'sales123',
          rememberMe: true,
        );
      });

      await tester.pumpWidget(buildProductsScreen());
      await tester.pumpAndSettle();

      expect(find.text('+ Add Product'), findsNothing);
    });

    testWidgets('Null user treated as non-admin (hides Add Product)', (
      WidgetTester tester,
    ) async {
      expect(ServiceLocator().authController.currentUser, isNull);

      await tester.pumpWidget(buildProductsScreen());
      await tester.pumpAndSettle();

      expect(find.text('+ Add Product'), findsNothing);
    });
  });

  group('Product Details Permissions', () {
    testWidgets('Admin sees Edit Product and Stock Actions', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await ServiceLocator().authController.login(
          username: 'admin',
          password: 'admin123',
          rememberMe: true,
        );
      });

      // We need a proper ProductCard to show Edit Product
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductCard(product: dummyProduct)),
        ),
      );
      await tester.pumpAndSettle();

      // Admin sees Edit Product on the card
      expect(find.text('Edit Product'), findsOneWidget);

      await tester.pumpWidget(buildProductDetailsScreen());
      await tester.pumpAndSettle(); // For async stock fetch

      // Stock Actions in details
      expect(find.text('Stock In'), findsOneWidget);
      expect(find.text('Stock Out'), findsOneWidget);
    });

    testWidgets('Salesperson does not see Edit Product or Stock Actions', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await ServiceLocator().authController.login(
          username: 'sales',
          password: 'sales123',
          rememberMe: true,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductCard(product: dummyProduct)),
        ),
      );
      await tester.pumpAndSettle();

      // Edit Product is hidden on card
      expect(find.text('Edit Product'), findsNothing);

      await tester.pumpWidget(buildProductDetailsScreen());
      await tester.pumpAndSettle();

      // Stock Actions are hidden in details
      expect(find.text('Stock In'), findsNothing);
      expect(find.text('Stock Out'), findsNothing);
    });
  });
}
