import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/presentation/create_quotation_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/selected_products_section.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/quotation_product_tile.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:sembast/sembast_memory.dart';
import '../../../../test/features/authentication/fake_auth_repository.dart';

void main() {
  group('CreateQuotationScreen Regression Tests', () {
    late Database db;

    late Product productA;
    late Product productB;
    late Product productC;

    setUpAll(() async {
      final dbName = 'test_create_quotation_${DateTime.now().millisecondsSinceEpoch}.db';
      db = await databaseFactoryMemory.openDatabase(dbName);
      DatabaseService().setDatabaseForTesting(db);

      ServiceLocator.resetForTesting();
      
      final localRepo = SembastProductRepository();
      
      productA = Product(
        id: 'prodA',
        productCode: 'PROD-A',
        name: 'Product A',
        category: 'Cat A',
        brand: 'Brand A',
        sellingPrice: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      productB = Product(
        id: 'prodB',
        productCode: 'PROD-B',
        name: 'Product B',
        category: 'Cat B',
        brand: 'Brand B',
        sellingPrice: 200,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      productC = Product(
        id: 'prodC',
        productCode: 'PROD-C',
        name: 'Product C',
        category: 'Cat C',
        brand: 'Brand C',
        sellingPrice: 300,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await localRepo.addProduct(productA);
      await localRepo.addProduct(productB);
      await localRepo.addProduct(productC);
      ServiceLocator().mockProductRepository = localRepo;

      ServiceLocator().mockAuthRepository = FakeAuthRepository();
      await ServiceLocator().init();
      
      ServiceLocator().authController.setCurrentUserForTesting(
        AppUser(
          id: 'test',
          name: 'Test User',
          username: 'testuser',
          passwordHash: 'hash',
          role: UserRole.sales,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      );

      await ServiceLocator().stockController.addStockIn(
        productId: 'prodA',
        quantity: 1,
        reference: 'init',
        movementDate: DateTime.now(),
        createdBy: 'system'
      );
      
      await ServiceLocator().stockController.addStockIn(
        productId: 'prodB',
        quantity: 5,
        reference: 'init',
        movementDate: DateTime.now(),
        createdBy: 'system'
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets('Quotation stock validation allows over-stock quoting with warnings', (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
          return;
        }
        if (originalOnError != null) originalOnError(details);
      };
      
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 1200,
            child: CreateQuotationScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Stock 1 / Qty 1 -> quantity accepted
      var section = tester.widget<SelectedProductsSection>(find.byType(SelectedProductsSection));
      section.onProductsAdded([productA]);
      await tester.pumpAndSettle();
      
      var tiles = tester.widgetList<QuotationProductTile>(find.byType(QuotationProductTile)).toList();
      expect(tiles.length, 1, reason: 'Product A added');
      expect(tiles[0].item.quantity, 1);
      
      // 2. Stock 1 / Qty 2 -> quantity remains 2 and is not reverted
      section = tester.widget<SelectedProductsSection>(find.byType(SelectedProductsSection));
      section.onQuantityChanged(tiles[0].item.id, 2);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100)); // wait for delayed fallback if any
      await tester.pumpAndSettle();
      
      tiles = tester.widgetList<QuotationProductTile>(find.byType(QuotationProductTile)).toList();
      expect(tiles[0].item.quantity, 2, reason: 'Quantity should NOT be reverted');
      expect(find.byType(SnackBar), findsWidgets, reason: 'Warning SnackBar should appear');
      
      ScaffoldMessenger.of(tester.element(find.byType(CreateQuotationScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // 3. Stock 5 / Qty 10 -> quantity remains 10 and is not blocked
      section = tester.widget<SelectedProductsSection>(find.byType(SelectedProductsSection));
      section.onProductsAdded([productB]);
      await tester.pumpAndSettle();
      
      tiles = tester.widgetList<QuotationProductTile>(find.byType(QuotationProductTile)).toList();
      expect(tiles.length, 2, reason: 'Product B added');
      
      section = tester.widget<SelectedProductsSection>(find.byType(SelectedProductsSection));
      section.onQuantityChanged(tiles[1].item.id, 10);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      
      tiles = tester.widgetList<QuotationProductTile>(find.byType(QuotationProductTile)).toList();
      expect(tiles[1].item.quantity, 10, reason: 'Quantity should be 10');
      expect(find.byType(SnackBar), findsWidgets, reason: 'Warning SnackBar should appear');

      ScaffoldMessenger.of(tester.element(find.byType(CreateQuotationScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // 4. Stock 0 / Qty 1 -> product/quantity is still accepted
      section = tester.widget<SelectedProductsSection>(find.byType(SelectedProductsSection));
      section.onProductsAdded([productC]);
      await tester.pumpAndSettle();
      
      tiles = tester.widgetList<QuotationProductTile>(find.byType(QuotationProductTile)).toList();
      expect(tiles.length, 3, reason: 'Product C added');
      expect(tiles[2].item.quantity, 1, reason: 'Quantity should be 1');
      expect(find.byType(SnackBar), findsWidgets, reason: 'Warning SnackBar should appear');
      
      ScaffoldMessenger.of(tester.element(find.byType(CreateQuotationScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Enter customer info so it allows saving
      await tester.enterText(find.widgetWithText(TextField, 'Customer Name *').first, 'Test Customer');
      await tester.pumpAndSettle();
      
      // Simulate tapping the save button
      await tester.tap(find.text('Save Draft').last);
      await tester.pumpAndSettle();
      
      // Should show 'Insufficient stock' warning and 'Quotation saved successfully'
      expect(find.byType(SnackBar), findsWidgets, reason: 'Should show snackbars on save');
      expect(find.text('Quotation saved successfully'), findsWidgets);
    });
  });
}
