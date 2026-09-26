import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/presentation/previous_quotations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ServiceLocator.resetForTesting);
  tearDown(ServiceLocator.resetForTesting);

  testWidgets('loading and failure hide summary; Retry reaches empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _QueuedQuotationRepository();
    final first = repository.enqueue();
    final second = repository.enqueue();
    ServiceLocator().mockQuotationRepository = repository;

    await tester.pumpWidget(
      const MaterialApp(home: PreviousQuotationsScreen()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Total Quotations'), findsNothing);
    expect(find.text('No quotations found.'), findsNothing);

    first.completeError(StateError('quotation load failed'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Total Quotations'), findsNothing);
    expect(find.text('No quotations found.'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    second.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('No quotations found.'), findsOneWidget);
  });
}

class _QueuedQuotationRepository implements QuotationRepository {
  final List<Completer<List<Quotation>>> _responses = [];
  int _next = 0;

  Completer<List<Quotation>> enqueue() {
    final completer = Completer<List<Quotation>>();
    _responses.add(completer);
    return completer;
  }

  @override
  Future<List<Quotation>> getAllQuotations() => _responses[_next++].future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
