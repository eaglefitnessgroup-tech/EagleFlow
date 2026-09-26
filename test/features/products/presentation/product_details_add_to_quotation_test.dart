import 'dart:typed_data';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/products/presentation/product_details_screen.dart';
import 'package:eagleflow/features/products/presentation/widgets/details/quantity_selector.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/presentation/create_quotation_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/quotation_product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
  late Product product;

  setUp(() {
    ServiceLocator.resetForTesting();
    product = Product(
      id: 'product-id',
      productCode: 'PRODUCT-001',
      name: 'Zero Stock Product',
      category: 'Equipment',
      brand: 'Eagle',
      sellingPrice: 1250,
      openingStock: 0,
      description: 'Full product specification',
      imageId: 'image-id',
      imageBytes: imageBytes,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2),
    );
  });

  tearDown(ServiceLocator.resetForTesting);

  testWidgets(
    'Add to Quotation opens Create with one complete zero-stock product line',
    (tester) async {
      Object? createArguments;
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailsScreen(testProduct: product),
          onGenerateRoute: (settings) {
            if (settings.name == '/create-quotation') {
              createArguments = settings.arguments;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const CreateQuotationScreen(),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      final quantitySelector = tester.widget<QuantitySelector>(
        find.byType(QuantitySelector),
      );
      quantitySelector.onChanged(3);
      await tester.pump();

      await tester.tap(find.text('Add to Quotation'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateQuotationScreen), findsOneWidget);
      expect(createArguments, isA<QuotationController>());

      final quotation = (createArguments as QuotationController).quotation;
      expect(quotation.lineItems, hasLength(1));
      final item = quotation.lineItems.single;
      expect(item.productId, product.id);
      expect(item.productCode, product.productCode);
      expect(item.name, product.name);
      expect(item.brand, product.brand);
      expect(item.unitPrice, product.sellingPrice);
      expect(item.quantity, 3);
      expect(item.imageId, product.imageId);
      expect(item.imageBytes, same(imageBytes));
      expect(item.description, product.description);
      final productTile = tester.widget<QuotationProductTile>(
        find.byType(QuotationProductTile),
      );
      expect(productTile.item.productId, product.id);
      expect(productTile.item.quantity, 3);
      expect(find.text('Product is out of stock'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('existing Product Details content remains visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductDetailsScreen(testProduct: product)),
    );
    await tester.pumpAndSettle();

    expect(find.text(product.name), findsOneWidget);
    expect(find.text(product.productCode), findsOneWidget);
    expect(find.text(product.brand), findsOneWidget);
    expect(find.text(product.description), findsOneWidget);
    expect(find.text('AED 1,250'), findsNWidgets(2));
    expect(find.byType(QuantitySelector), findsOneWidget);
    expect(find.text('Add to Quotation'), findsOneWidget);
  });

  testWidgets('Product Details shows the saved condition label', (
    tester,
  ) async {
    product = product.copyWith(condition: ProductCondition.refurbished);

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailsScreen(testProduct: product)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Condition: Refurbished'), findsOneWidget);
  });

  testWidgets('Product Details safely hides a null legacy condition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductDetailsScreen(testProduct: product)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Condition:'), findsNothing);
    expect(find.text(product.productCode), findsOneWidget);
  });
}
