import 'dart:async';
import 'dart:convert';

import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/presentation/bulk_update_products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../features/authentication/fake_auth_repository.dart';

void main() {
  late List<Product> products;
  late String csvData;
  String? savedFilename;
  List<int>? savedBytes;
  int productLoadCount = 0;
  late List<String> updatedProductIds;
  late List<ProductUpdatePatch> receivedPatches;
  Completer<Product>? pendingUpdate;
  int? failProductLoadOnCall;

  setUp(() async {
    ServiceLocator.resetForTesting();
    SupabaseService.resetForTesting();
    ServiceLocator().mockAuthRepository = FakeAuthRepository();
    await ServiceLocator().authController.logout();

    products = [
      _product(
        id: 'product-1',
        code: 'SKU-001',
        name: 'Original name',
        price: 25,
      ),
      _product(
        id: 'product-2',
        code: 'SKU-002',
        name: 'Second product',
        price: 10,
      ),
      _product(
        id: 'product-3',
        code: 'DUP',
        name: 'Duplicate source',
        price: 10,
      ),
      _product(
        id: 'product-4',
        code: 'SKU-003',
        name: 'Third product',
        price: 10,
      ),
    ];
    csvData =
        'Product Code,Product Name,Selling Price,VAT Applicable\n'
        'SKU-001,Updated name,30,No\n'
        'SKU-002,Second product,10,Yes\n'
        'UNKNOWN,Unknown name,10,Yes\n'
        'DUP,First duplicate,10,Yes\n'
        ' dup ,Second duplicate,10,Yes\n'
        'SKU-003,Third product,not-a-number,Yes';
    savedFilename = null;
    savedBytes = null;
    productLoadCount = 0;
    updatedProductIds = [];
    receivedPatches = [];
    pendingUpdate = null;
    failProductLoadOnCall = null;
  });

  tearDown(() async {
    ServiceLocator.resetForTesting();
    SupabaseService.resetForTesting();
  });

  Future<void> loginAdmin() async {
    await ServiceLocator().authController.login(
      email: 'anshad@eagleflow.com',
      password: 'anshad123',
      rememberMe: false,
    );
  }

  Future<void> loginSales() async {
    await ServiceLocator().authController.login(
      email: 'ajmal@eagleflow.com',
      password: 'ajmal123',
      rememberMe: false,
    );
  }

  Future<List<Product>> loadProducts() async {
    productLoadCount++;
    if (productLoadCount == failProductLoadOnCall) {
      throw StateError('refresh failed');
    }
    return products;
  }

  Future<Map<String, List<int>>?> pickCsv() async {
    return {'updates.csv': utf8.encode(csvData)};
  }

  Future<void> saveFile({
    required List<int> bytes,
    required String filename,
  }) async {
    savedBytes = bytes;
    savedFilename = filename;
  }

  Future<Product> updateProductFields(
    String productId,
    ProductUpdatePatch patch,
  ) async {
    updatedProductIds.add(productId);
    receivedPatches.add(patch);
    if (pendingUpdate != null) return pendingUpdate!.future;
    return products.firstWhere((product) => product.id == productId);
  }

  Widget buildApp({String? fileData}) {
    return MaterialApp(
      routes: {
        AppRoutes.dashboard: (_) => const Scaffold(body: Text('Dashboard')),
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
      },
      home: BulkUpdateProductsScreen(
        currentProductsLoader: loadProducts,
        filePicker: fileData == null
            ? pickCsv
            : () async => {'updates.csv': utf8.encode(fileData)},
        fileSaver: saveFile,
        productFieldsUpdater: updateProductFields,
      ),
    );
  }

  Future<void> pumpAdminScreen(WidgetTester tester, {String? fileData}) async {
    await tester.runAsync(loginAdmin);
    await tester.pumpWidget(buildApp(fileData: fileData));
    await tester.pumpAndSettle();
  }

  Future<void> selectFile(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('select_update_file_btn')));
    await tester.pumpAndSettle();
  }

  testWidgets('admin can render Bulk Update Products screen', (tester) async {
    await pumpAdminScreen(tester);

    expect(find.text('Bulk Update Products'), findsOneWidget);
    expect(find.text('Download Current Products'), findsOneWidget);
    expect(find.text('Select Excel File'), findsOneWidget);
  });

  testWidgets('non-admin access is denied by AdminGuard', (tester) async {
    await tester.runAsync(loginSales);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Admin access required.'), findsOneWidget);
    expect(
      find.byKey(const Key('download_current_products_btn')),
      findsNothing,
    );
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('Download Current Products invokes export path', (tester) async {
    await pumpAdminScreen(tester);

    await tester.tap(find.byKey(const Key('download_current_products_btn')));
    await tester.pumpAndSettle();

    expect(productLoadCount, 1);
    expect(savedFilename, 'EagleFlow_Product_Bulk_Update.xlsx');
    expect(savedBytes, isNotEmpty);
    expect(find.text('Current products Excel downloaded.'), findsOneWidget);
  });

  testWidgets('selecting a valid file shows preview rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(productLoadCount, 1);
    expect(find.text('updates.csv'), findsOneWidget);
    expect(find.text('SKU-001'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
  });

  testWidgets('actual Old to New fields are displayed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(find.text('Product Name'), findsOneWidget);
    expect(find.text('Original name → Updated name'), findsOneWidget);
    expect(find.text('Selling Price'), findsOneWidget);
    expect(find.text('AED 25.00 → AED 30.00'), findsOneWidget);
    expect(find.text('VAT Applicable'), findsOneWidget);
    expect(find.text('Yes → No'), findsOneWidget);
  });

  testWidgets('noChanges row displays correctly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(find.byKey(const Key('status_noChanges')), findsOneWidget);
    expect(find.text('No changes detected.'), findsOneWidget);
  });

  testWidgets('unknown Product Code displays reason', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(find.text('Unknown Product'), findsOneWidget);
    expect(find.text('Unknown Product Code'), findsOneWidget);
  });

  testWidgets('duplicate code displays reason', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(find.text('Duplicate Code'), findsNWidgets(2));
    expect(
      find.text('Duplicate Product Code in uploaded file'),
      findsNWidgets(2),
    );
  });

  testWidgets('invalid row displays reason', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(find.text('Invalid'), findsOneWidget);
    expect(
      find.textContaining('Selling Price must be a finite number'),
      findsOneWidget,
    );
  });

  testWidgets('summary counts are correct', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('summary_valid')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('summary_no_changes')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('summary_unknown')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('summary_invalid')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('blank initial state is clean', (tester) async {
    await pumpAdminScreen(tester);

    expect(find.byKey(const Key('bulk_update_empty_state')), findsOneWidget);
    expect(find.text('No update file selected.'), findsOneWidget);
    expect(find.byKey(const Key('bulk_update_summary')), findsNothing);
    expect(find.byKey(const Key('bulk_update_validation_error')), findsNothing);
  });

  testWidgets('Update Products requires confirmation before mutation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('update_products_btn')),
    );

    expect(button.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('update_products_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Update 1 product?'), findsOneWidget);
    expect(updatedProductIds, isEmpty);
    expect(productLoadCount, 1);

    await tester.tap(find.byKey(const Key('cancel_bulk_update_btn')));
    await tester.pumpAndSettle();
    expect(updatedProductIds, isEmpty);
  });

  testWidgets('confirmed update shows results and refreshes once afterward', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);
    await selectFile(tester);

    await tester.tap(find.byKey(const Key('update_products_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_bulk_update_btn')));
    await tester.pumpAndSettle();

    expect(updatedProductIds, ['product-1']);
    expect(receivedPatches.single.productName, 'Updated name');
    expect(receivedPatches.single.sellingPrice, 30);
    expect(receivedPatches.single.vatApplicable, isFalse);
    expect(productLoadCount, 3);
    expect(find.text('Succeeded: 1'), findsOneWidget);
    expect(find.text('Skipped: 5'), findsOneWidget);
    expect(find.text('Failed: 0'), findsOneWidget);
    expect(find.text('Updated successfully'), findsOneWidget);
  });

  testWidgets('progress disables actions and prevents duplicate submission', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    pendingUpdate = Completer<Product>();
    await pumpAdminScreen(tester);
    await selectFile(tester);

    await tester.tap(find.byKey(const Key('update_products_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_bulk_update_btn')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('bulk_update_progress')), findsOneWidget);
    expect(find.text('Updating 1 of 1…'), findsWidgets);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('update_products_btn')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('select_update_file_btn')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('download_current_products_btn')),
          )
          .onPressed,
      isNull,
    );
    expect(updatedProductIds, ['product-1']);

    pendingUpdate!.complete(products.first);
    await tester.pumpAndSettle();
    expect(updatedProductIds, ['product-1']);
    expect(find.text('Succeeded: 1'), findsOneWidget);
  });

  testWidgets('final refresh failure preserves actual update results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    failProductLoadOnCall = 3;
    await pumpAdminScreen(tester);
    await selectFile(tester);

    await tester.tap(find.byKey(const Key('update_products_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_bulk_update_btn')));
    await tester.pumpAndSettle();

    expect(updatedProductIds, ['product-1']);
    expect(find.text('Succeeded: 1'), findsOneWidget);
    expect(find.byKey(const Key('bulk_update_refresh_error')), findsOneWidget);
    expect(find.textContaining('final refresh failed'), findsOneWidget);
  });

  testWidgets('Update button is disabled when no valid changes exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(
      tester,
      fileData: 'Product Code,Product Name\nSKU-002,Second product',
    );

    await selectFile(tester);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('update_products_btn')),
    );

    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('status_noChanges')), findsOneWidget);
  });

  testWidgets('mobile layout has no overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAdminScreen(tester);

    await selectFile(tester);

    for (
      var attempt = 0;
      attempt < 8 && find.byKey(const Key('preview_code_2')).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('bulk_update_summary')), findsOneWidget);
    expect(find.byKey(const Key('preview_code_2')), findsOneWidget);
  });
}

Product _product({
  required String id,
  required String code,
  required String name,
  required double price,
}) {
  return Product(
    id: id,
    productCode: code,
    name: name,
    category: 'Equipment',
    brand: 'Premier',
    sellingPrice: price,
    unit: 'Nos',
    minStockLevel: 5,
    description: 'Description',
    isVatApplicable: true,
    isActive: true,
    openingStock: 20,
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
  );
}
