import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ServiceLocator.resetForTesting);
  tearDown(ServiceLocator.resetForTesting);

  testWidgets(
    'loading hides empty UI and failure retry reaches genuine empty',
    (tester) async {
      final repository = _QueuedProductRepository();
      final first = repository.enqueue();
      final second = repository.enqueue();
      final locator = ServiceLocator()..mockProductRepository = repository;

      final initialLoad = locator.productMasterController.loadProducts();
      await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('0 Products'), findsNothing);
      expect(find.text('No products found'), findsNothing);

      first.completeError(StateError('product load failed'));
      await expectLater(initialLoad, throwsA(isA<StateError>()));
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('0 Products'), findsNothing);
      expect(find.text('No products found'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      second.complete(const []);
      await tester.pumpAndSettle();

      expect(find.text('0 Products'), findsOneWidget);
      expect(find.text('No products found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );
}

class _QueuedProductRepository implements ProductRepository {
  final List<Completer<List<Product>>> _responses = [];
  int _next = 0;

  Completer<List<Product>> enqueue() {
    final completer = Completer<List<Product>>();
    _responses.add(completer);
    return completer;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Product>> getAllProducts() => _responses[_next++].future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
