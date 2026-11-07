import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/stock/presentation/stock_out_by_quotation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../authentication/fake_auth_repository.dart';

void main() {
  setUp(ServiceLocator.resetForTesting);
  tearDown(ServiceLocator.resetForTesting);

  testWidgets('disposing during quotation lookup does not call setState', (
    tester,
  ) async {
    final lookup = Completer<Quotation?>();
    final locator = ServiceLocator()
      ..mockAuthRepository = FakeAuthRepository()
      ..mockQuotationRepository = _DelayedQuotationRepository(lookup.future);
    final now = DateTime(2026, 1, 1);
    locator.authController.setCurrentUserForTesting(
      AppUser(
        id: 'admin-1',
        name: 'Admin',
        username: 'admin',
        passwordHash: '',
        role: UserRole.admin,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: StockOutByQuotationScreen()),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'QT-0001-26');
    await tester.tap(find.text('Find Quotation'));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    lookup.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _DelayedQuotationRepository implements QuotationRepository {
  _DelayedQuotationRepository(this.lookup);

  final Future<Quotation?> lookup;

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) => lookup;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
