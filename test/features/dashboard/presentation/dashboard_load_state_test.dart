import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ServiceLocator.resetForTesting);
  tearDown(ServiceLocator.resetForTesting);

  testWidgets('failure hides counters and Retry can reach successful empty', (
    tester,
  ) async {
    final productRepository = _QueuedProductRepository();
    final first = productRepository.enqueue();
    final second = productRepository.enqueue();
    final locator = ServiceLocator()
      ..mockProductRepository = productRepository
      ..mockQuotationRepository = _EmptyQuotationRepository();

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0'), findsNothing);

    first.completeError(StateError('dashboard product load failed'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('0'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    second.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);
    expect(find.text('0'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('No quotations yet'), findsOneWidget);
    expect(locator.productRepository, same(productRepository));
  });
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
  Future<List<Product>> getAllProducts() => _responses[_next++].future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyQuotationRepository implements QuotationRepository {
  @override
  Future<List<Quotation>> getAllQuotations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
