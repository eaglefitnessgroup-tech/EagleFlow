import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/products/presentation/add_edit_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../authentication/fake_auth_repository.dart';

class _RecordingProductRepository implements ProductRepository {
  Product? savedProduct;

  @override
  Future<Product> addProduct(Product product) async {
    savedProduct = product;
    return product;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    savedProduct = product;
    return product;
  }

  @override
  Future<List<Product>> getAllProducts() async {
    return savedProduct == null ? [] : [savedProduct!];
  }

  @override
  Future<bool> isProductCodeUnique(String code, {String? excludeId}) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingProductRepository repository;
  late FakeAuthRepository authRepository;

  Product existingProduct({ProductCondition? condition}) {
    return Product(
      id: 'product-1',
      productCode: 'SKU-001',
      name: 'Existing Product',
      category: 'Strength',
      brand: 'Eagle',
      sellingPrice: 100,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2),
      condition: condition,
    );
  }

  setUp(() {
    ServiceLocator.resetForTesting();
    repository = _RecordingProductRepository();
    authRepository = FakeAuthRepository();
    ServiceLocator().mockProductRepository = repository;
    ServiceLocator().mockAuthRepository = authRepository;
    ServiceLocator().authController.setCurrentUserForTesting(
      authRepository.testAdmin,
    );
  });

  tearDown(ServiceLocator.resetForTesting);

  Future<void> pumpForm(WidgetTester tester, {Product? product}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AddEditProductScreen(
          product: product,
          allowAuthenticatedCreate: true,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> selectCondition(
    WidgetTester tester,
    ProductCondition condition,
  ) async {
    await tester.tap(find.byKey(const Key('product-condition-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(condition.displayLabel).last);
    await tester.pumpAndSettle();
  }

  Future<void> completeRequiredFields(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Code / SKU *'),
      'SKU-NEW',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Name *'),
      'New Product',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Selling Price *'),
      '250',
    );
  }

  testWidgets(
    'Add Product shows optional Condition dropdown with four options',
    (tester) async {
      await pumpForm(tester);

      expect(find.byKey(const Key('product-condition-field')), findsOneWidget);
      expect(find.text('Select condition (optional)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('product-condition-field')));
      await tester.pumpAndSettle();

      for (final condition in ProductCondition.values) {
        expect(find.text(condition.displayLabel), findsOneWidget);
      }
    },
  );

  for (final condition in [
    ProductCondition.used,
    ProductCondition.refurbished,
  ]) {
    testWidgets('selecting ${condition.displayLabel} saves its condition', (
      tester,
    ) async {
      await pumpForm(tester);
      await completeRequiredFields(tester);
      await selectCondition(tester, condition);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedProduct?.condition, condition);
    });
  }

  testWidgets('editing a Display product preselects Display', (tester) async {
    await pumpForm(
      tester,
      product: existingProduct(condition: ProductCondition.display),
    );

    final field = tester.widget<DropdownButtonFormField<ProductCondition>>(
      find.byKey(const Key('product-condition-field')),
    );
    expect(field.initialValue, ProductCondition.display);
    expect(find.text('Display'), findsOneWidget);
  });

  testWidgets(
    'legacy null condition remains unselected and does not become New',
    (tester) async {
      await pumpForm(tester, product: existingProduct());

      final field = tester.widget<DropdownButtonFormField<ProductCondition>>(
        find.byKey(const Key('product-condition-field')),
      );
      expect(field.initialValue, isNull);
      expect(find.text('Select condition (optional)'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.savedProduct?.condition, isNull);
    },
  );

  testWidgets('existing required-field validation is unchanged', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Required'), findsNWidgets(3));
    expect(repository.savedProduct, isNull);
  });
}
