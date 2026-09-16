import 'dart:async';

import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/create_quotation_screen.dart';
import 'package:eagleflow/features/quotations/presentation/quotation_preview_screen.dart';
import 'package:eagleflow/features/quotations/presentation/widgets/create/quotation_information_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthRepository implements AuthRepository {
  _AuthRepository(this.currentUser, this.profiles);

  final AppUser currentUser;
  final List<AppUser> profiles;

  @override
  Future<AppUser?> getCurrentUser() async => currentUser;

  @override
  Future<List<AppUser>> getUsers() async => profiles;

  @override
  Future<AuthResult> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasRememberedSession() async => true;

  @override
  Future<void> clearRememberedSession() async {}
}

class _DelayedAuthRepository implements AuthRepository {
  final Completer<List<AppUser>> profiles = Completer<List<AppUser>>();

  @override
  Future<AppUser?> getCurrentUser() async => null;

  @override
  Future<List<AppUser>> getUsers() => profiles.future;

  @override
  Future<AuthResult> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasRememberedSession() async => false;

  @override
  Future<void> clearRememberedSession() async {}
}

void main() {
  AppUser testUser(String id, String name) {
    final now = DateTime(2026, 9, 16);
    return AppUser(
      id: id,
      name: name,
      username: name.toLowerCase(),
      passwordHash: '',
      role: UserRole.sales,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('new quotation uses the current user ID and name', (tester) async {
    final shijo = testUser('SHIJO-ACTUAL-ID', 'Shijo');

    ServiceLocator.resetForTesting();
    final locator = ServiceLocator();
    locator.mockAuthRepository = _AuthRepository(shijo, const []);
    locator.authController.setCurrentUserForTesting(shijo);

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CreateQuotationScreen()),
    );
    await tester.pump();

    final information = tester.widget<QuotationInformationCard>(
      find.byType(QuotationInformationCard),
    );
    expect(information.salespersonId, shijo.id);
    expect(information.salespersonName, 'Shijo');
  });

  testWidgets('preview shows current Shijo instead of stale Nabeel profile', (
    tester,
  ) async {
    final shijo = testUser('SALES-003', 'Shijo');
    final staleNabeel = shijo.copyWith(name: 'Nabeel', username: 'nabeel');

    ServiceLocator.resetForTesting();
    final locator = ServiceLocator();
    locator.mockAuthRepository = _AuthRepository(shijo, [staleNabeel]);
    locator.authController.setCurrentUserForTesting(shijo);

    final quotation = QuotationDefaults.createEmptyDraft(
      salespersonId: shijo.id,
    ).copyWith(customerInfo: const CustomerInfo(name: 'Customer'));
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

    expect(find.text('Shijo'), findsOneWidget);
    expect(find.text('Nabeel'), findsNothing);
  });

  testWidgets(
    'stale async preview lookup cannot overwrite the current user name',
    (tester) async {
      final shijo = testUser('SALES-003', 'Shijo');
      final staleNabeel = shijo.copyWith(name: 'Nabeel', username: 'nabeel');
      final authRepository = _DelayedAuthRepository();

      ServiceLocator.resetForTesting();
      final locator = ServiceLocator();
      locator.mockAuthRepository = authRepository;
      locator.authController.setCurrentUserForTesting(null);

      final quotation = QuotationDefaults.createEmptyDraft(
        salespersonId: shijo.id,
      ).copyWith(customerInfo: const CustomerInfo(name: 'Customer'));
      final controller = QuotationController(quotation);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: controller),
            builder: (_) => const QuotationPreviewScreen(),
          ),
        ),
      );
      await tester.pump();

      locator.authController.setCurrentUserForTesting(shijo);
      authRepository.profiles.complete([staleNabeel]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Shijo'), findsOneWidget);
      expect(find.text('Nabeel'), findsNothing);
    },
  );
}
