import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQuotationRepository implements QuotationRepository {
  final savedInputs = <Quotation>[];
  Completer<Quotation>? pendingSave;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    savedInputs.add(quotation);
    if (pendingSave != null) return pendingSave!.future;
    if (quotation.id.isEmpty) {
      return quotation.copyWith(
        id: 'assigned-id',
        quotationNumber: 'QT-ASSIGNED',
      );
    }
    return quotation;
  }

  @override
  Future<void> deleteQuotation(String id) => throw UnimplementedError();

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) =>
      throw UnimplementedError();

  @override
  Future<List<Quotation>> getAllQuotations() => throw UnimplementedError();

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) =>
      throw UnimplementedError();

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) =>
      throw UnimplementedError();
}

void main() {
  late _FakeQuotationRepository repository;
  late AppUser salesperson;

  setUp(() {
    ServiceLocator.resetForTesting();
    repository = _FakeQuotationRepository();
    ServiceLocator().mockQuotationRepository = repository;
    salesperson = AppUser(
      id: 'salesperson-id',
      name: 'Sales Person',
      username: 'sales.person',
      passwordHash: '',
      role: UserRole.sales,
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );
    ServiceLocator().authController.setCurrentUserForTesting(salesperson);
  });

  tearDown(ServiceLocator.resetForTesting);

  Future<QuotationController> pumpPreview(
    WidgetTester tester,
    Quotation quotation,
  ) async {
    final controller = QuotationController(quotation);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: controller),
          builder: (_) => const QuotationPreviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('Save updates an existing quotation and remains on Preview', (
    tester,
  ) async {
    final quotation = QuotationDefaults.createEmptyDraft(
      salespersonId: salesperson.id,
    ).copyWith(id: 'existing-id', quotationNumber: 'QT-EXISTING');
    final controller = await pumpPreview(tester, quotation);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedInputs, hasLength(1));
    expect(repository.savedInputs.single.id, 'existing-id');
    expect(repository.savedInputs.single.quotationNumber, 'QT-EXISTING');
    expect(controller.quotation.id, 'existing-id');
    expect(controller.quotation.quotationNumber, 'QT-EXISTING');
    expect(find.byType(QuotationPreviewScreen), findsOneWidget);
    expect(find.text('Quotation saved'), findsOneWidget);
  });

  testWidgets('first save retains assigned identity for subsequent updates', (
    tester,
  ) async {
    final quotation = QuotationDefaults.createEmptyDraft(
      salespersonId: salesperson.id,
    );
    final controller = await pumpPreview(tester, quotation);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedInputs, hasLength(2));
    expect(repository.savedInputs.first.id, isEmpty);
    expect(repository.savedInputs.last.id, 'assigned-id');
    expect(repository.savedInputs.last.quotationNumber, 'QT-ASSIGNED');
    expect(controller.quotation.id, 'assigned-id');
    expect(controller.quotation.quotationNumber, 'QT-ASSIGNED');
  });

  testWidgets('Save ignores repeated taps while persistence is in progress', (
    tester,
  ) async {
    final quotation = QuotationDefaults.createEmptyDraft(
      salespersonId: salesperson.id,
    ).copyWith(id: 'existing-id', quotationNumber: 'QT-EXISTING');
    repository.pendingSave = Completer<Quotation>();
    await pumpPreview(tester, quotation);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump();

    expect(repository.savedInputs, hasLength(1));

    repository.pendingSave!.complete(quotation);
    await tester.pumpAndSettle();
  });
}
