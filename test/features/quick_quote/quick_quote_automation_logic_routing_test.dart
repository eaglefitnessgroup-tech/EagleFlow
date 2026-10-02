import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_automation_logic_controller.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_config_repository.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_configuration.dart';
import 'package:eagleflow/features/quick_quote/presentation/quick_quote_automation_logic_screen.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'quick_quote_config_test_fixture.dart';

void main() {
  late _EmptyConfigRepository repository;

  setUp(() async {
    ServiceLocator.resetForTesting();
    final database = await databaseFactoryMemory.openDatabase(
      'automation_logic_route_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);
    repository = _EmptyConfigRepository();
    ServiceLocator()
      ..mockAuthRepository = _NoOpAuthRepository()
      ..mockQuickQuoteConfigRepository = repository;
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  test('registers the admin Automation Logic named route', () {
    expect(
      AppRoutes.quickQuoteAutomationLogic,
      '/admin/quick-quote-automation-logic',
    );
    expect(AppRoutes.routes, contains(AppRoutes.quickQuoteAutomationLogic));
  });

  testWidgets('admin can open the management route', (tester) async {
    ServiceLocator().authController.setCurrentUserForTesting(
      _user(admin: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.quickQuoteAutomationLogic,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuickQuoteAutomationLogicScreen), findsOneWidget);
    expect(find.text('Quick Quote Automation Logic'), findsOneWidget);
    expect(find.text('No active automation configuration.'), findsOneWidget);
    expect(repository.historyCalls, 1);
  });

  testWidgets('non-admin direct navigation is blocked and redirected', (
    tester,
  ) async {
    ServiceLocator().authController.setCurrentUserForTesting(
      _user(admin: false),
    );
    final controller = QuickQuoteAutomationLogicController(
      repository: repository,
      productLoader: () async => const [],
      isAdmin: () => ServiceLocator().authController.isAdmin,
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.dashboard: (_) =>
              const Scaffold(body: Text('Safe Dashboard')),
          AppRoutes.quickQuoteAutomationLogic: (_) =>
              QuickQuoteAutomationLogicScreen(controller: controller),
        },
        initialRoute: AppRoutes.quickQuoteAutomationLogic,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safe Dashboard'), findsOneWidget);
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(repository.historyCalls, 0);
  });

  testWidgets('validation errors are visible and keep Apply disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ServiceLocator().authController.setCurrentUserForTesting(
      _user(admin: true),
    );
    final workbook = buildValidConfigWorkbook();
    setWorkbookCell(
      workbook,
      QuickQuoteConfigWorkbookService.profileSheet,
      'D6',
      TextCellValue('invalid'),
    );
    final controller = _controller(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: QuickQuoteAutomationLogicScreen(
          controller: controller,
          filePicker: () async =>
              MapEntry('invalid.xlsx', encodeWorkbook(workbook)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-automation-excel')));
    await tester.pumpAndSettle();

    expect(find.text('VALIDATION SUMMARY'), findsOneWidget);
    expect(
      find.textContaining('Budget Min must be a valid number'),
      findsOneWidget,
    );
    final applyFinder = find.byKey(const Key('apply-automation-logic'));
    await tester.scrollUntilVisible(
      applyFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final apply = tester.widget<FilledButton>(applyFinder);
    expect(apply.onPressed, isNull);
  });

  testWidgets('valid workbook enables Apply and renders preview diff', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ServiceLocator().authController.setCurrentUserForTesting(
      _user(admin: true),
    );
    final controller = _controller(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: QuickQuoteAutomationLogicScreen(
          controller: controller,
          filePicker: () async => MapEntry(
            'valid.xlsx',
            encodeWorkbook(buildValidConfigWorkbook()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-automation-excel')));
    await tester.pumpAndSettle();

    final apply = tester.widget<FilledButton>(
      find.byKey(const Key('apply-automation-logic')),
    );
    expect(apply.onPressed, isNotNull);
    final preview = find.byKey(const Key('preview-automation-changes'));
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('automation-diff-preview')), findsOneWidget);
  });
}

QuickQuoteAutomationLogicController _controller(
  QuickQuoteConfigRepository repository,
) => QuickQuoteAutomationLogicController(
  repository: repository,
  productLoader: () async => buildConfigProducts(),
  isAdmin: () => ServiceLocator().authController.isAdmin,
);

AppUser _user({required bool admin}) {
  final now = DateTime(2026, 10, 2);
  return AppUser(
    id: admin ? 'ADMIN-001' : 'SALES-001',
    name: admin ? 'Admin' : 'Sales',
    username: admin ? 'admin' : 'sales',
    passwordHash: '',
    role: admin ? UserRole.admin : UserRole.sales,
    createdAt: now,
    updatedAt: now,
  );
}

class _EmptyConfigRepository implements QuickQuoteConfigRepository {
  int historyCalls = 0;

  @override
  Future<QuickQuoteConfiguration?> getActiveConfiguration() async => null;

  @override
  Future<List<QuickQuoteConfigVersion>> getVersionHistory() async {
    historyCalls++;
    return const [];
  }

  @override
  Future<QuickQuoteConfiguration> activateVersion(String versionId) {
    throw UnimplementedError();
  }

  @override
  Future<QuickQuoteConfiguration> applyConfiguration({
    required String sourceFilename,
    required QuickQuoteConfiguration configuration,
    required QuickQuoteConfigValidationSummary validationSummary,
  }) {
    throw UnimplementedError();
  }
}

class _NoOpAuthRepository implements AuthRepository {
  @override
  Future<void> clearRememberedSession() async {}

  @override
  Future<AppUser?> getCurrentUser() async => null;

  @override
  Future<List<AppUser>> getUsers() async => const [];

  @override
  Future<bool> hasRememberedSession() async => false;

  @override
  Future<AuthResult> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}
}
