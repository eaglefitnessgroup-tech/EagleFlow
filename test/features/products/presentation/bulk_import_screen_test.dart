import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:eagleflow/features/products/presentation/bulk_import_screen.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/guards/admin_guard.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import '../../../features/authentication/fake_auth_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _validCsvRow =
    'Product Code,Name,Category,Brand,Selling Price,Opening Stock,Min Stock Level,Unit,VAT Applicable,Active,Description,Model Number,Notes\n'
    'TEST1,Item,Cat,Brand,10.0,0,0,Nos,Yes,Yes,Desc,Mod,Not';

const _invalidCsvRow =
    'Product Code,Name,Category,Brand,Selling Price,Opening Stock,Min Stock Level,Unit,VAT Applicable,Active,Description,Model Number,Notes\n'
    'TEST1,Item,Cat,Brand,-10.0,0,0,Nos,Yes,Yes,Desc,Mod,Not';

/// A no-op [FileSaver] that records the last call's filename for assertions.
/// Used in all tests to avoid calling path_provider or web APIs.
String? _lastSavedFilename;
Future<void> _capturingSaver({
  required List<int> bytes,
  required String filename,
}) async {
  _lastSavedFilename = filename;
}

/// A [FileSaver] that always throws to simulate a save failure.
Future<void> _failingSaver({
  required List<int> bytes,
  required String filename,
}) async {
  throw Exception('Disk full');
}

/// Sets up the FilePicker method channel mock to return [csvContent].
void _mockFilePicker(String csvContent, {String filename = 'test.csv'}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'custom' ||
              methodCall.method == 'pickFiles' ||
              methodCall.method == 'any') {
            return [
              {
                'name': filename,
                'path': '/test/$filename',
                'bytes': utf8.encode(csvContent),
                'size': csvContent.length,
              },
            ];
          }
          return null;
        },
      );
}

void main() {
  setUp(() async {
    _lastSavedFilename = null;

    ServiceLocator.resetForTesting();
    SupabaseService.resetForTesting();

    final dbName =
        'test_bulk_import_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryMemory.openDatabase(dbName);
    DatabaseService().setDatabaseForTesting(db);

    ServiceLocator().mockAuthRepository = FakeAuthRepository();
    await ServiceLocator().init();
    await ServiceLocator().authController.logout();

    _mockFilePicker(_validCsvRow);
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
    SupabaseService.resetForTesting();
  });

  /// Builds a [MaterialApp] with the given child.
  /// [fileSaver] defaults to [_capturingSaver] so all tests avoid real I/O.
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: child,
      routes: {
        AppRoutes.dashboard: (_) => const Scaffold(body: Text('Dashboard')),
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
      },
    );
  }

  /// Shorthand: [BulkImportScreen] with [_capturingSaver] injected.
  BulkImportScreen screen({FileSaver? fileSaver}) =>
      BulkImportScreen(fileSaver: fileSaver ?? _capturingSaver);

  Future<void> loginAdmin(WidgetTester tester) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(
        username: 'anshad',
        password: 'anshad123',
        rememberMe: false,
      );
    });
  }

  Future<void> loginSales(WidgetTester tester) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(
        username: 'ajmal',
        password: 'ajmal123',
        rememberMe: false,
      );
    });
  }

  // ── access control ─────────────────────────────────────────────────────────

  testWidgets('Admin sees Import action', (tester) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(const ProductsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Bulk Import'), findsOneWidget);
  });

  testWidgets('Salesperson does not see Import action', (tester) async {
    await loginSales(tester);
    await tester.pumpWidget(buildApp(const ProductsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Bulk Import'), findsNothing);
  });

  testWidgets('Direct route blocked for Salesperson', (tester) async {
    await loginSales(tester);
    await tester.pumpWidget(buildApp(AdminGuard(child: screen())));
    await tester.pumpAndSettle();

    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.byType(BulkImportScreen), findsNothing);
  });

  // ── initial state ──────────────────────────────────────────────────────────

  testWidgets('Shows Choose ZIP File button on initial state', (tester) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose ZIP File'), findsOneWidget);
  });

  testWidgets('Shows Excel Template and Sample ZIP download buttons', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    expect(find.text('Excel Template'), findsOneWidget);
    expect(find.text('Sample ZIP'), findsOneWidget);
  });

  // ── CSV parse and preview ──────────────────────────────────────────────────

  testWidgets('Valid CSV shows Confirm Import button', (tester) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_zip_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Import'), findsOneWidget);
  });

  testWidgets('Invalid rows disable Confirm Import button', (tester) async {
    _mockFilePicker(_invalidCsvRow, filename: 'invalid.csv');

    // Larger viewport so the preview table has room to render.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_zip_btn')));
    await tester.pumpAndSettle();

    // Confirm Import button must be disabled (invalid row present)
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('confirm_import_btn')),
    );
    expect(btn.onPressed, isNull);
  });

  // ── summary bar ────────────────────────────────────────────────────────────

  testWidgets('Summary bar shows valid/invalid counts after parse', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_zip_btn')));
    await tester.pumpAndSettle();

    // Summary bar should appear
    expect(find.byKey(const Key('summary_bar')), findsOneWidget);
    // Valid count — 1 row
    expect(find.text('1'), findsWidgets);
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Invalid'), findsOneWidget);
  });

  // ── image column ──────────────────────────────────────────────────────────

  testWidgets('Preview table shows Image column header', (tester) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_zip_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Image'), findsOneWidget);
  });

  // ── offline state ──────────────────────────────────────────────────────────

  testWidgets('Offline banner visible when disconnected', (tester) async {
    // Supabase is not connected in tests by default.
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline_banner')), findsOneWidget);
  });

  testWidgets('Confirm Import blocked offline (button disabled)', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_zip_btn')));
    await tester.pumpAndSettle();

    // Offline → button disabled (isOnline=false)
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('confirm_import_btn')),
    );
    expect(btn.onPressed, isNull);
  });

  // ── file name display ──────────────────────────────────────────────────────

  testWidgets('Picked filename is shown after selection', (tester) async {
    _mockFilePicker(_validCsvRow, filename: 'products.csv');

    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_zip_btn')));
    await tester.pumpAndSettle();

    expect(find.text('products.csv'), findsOneWidget);
  });

  // ── template / sample download ─────────────────────────────────────────────

  testWidgets('Excel Template button triggers save and shows snackbar', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('download_template_btn')));
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // Correct filename passed to saver
    expect(_lastSavedFilename, 'products_import_template.xlsx');
    // Success snackbar visible
    expect(find.textContaining('Template downloaded'), findsOneWidget);
  });

  testWidgets('Sample ZIP button triggers save and shows snackbar', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('download_sample_btn')));
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // Correct filename passed to saver
    expect(_lastSavedFilename, 'products_sample_import.zip');
    // Success snackbar visible
    expect(find.textContaining('Sample downloaded'), findsOneWidget);
  });

  testWidgets('Template save failure shows friendly error message', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen(fileSaver: _failingSaver)));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('download_template_btn')));
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // No raw exception — friendly message shown in status area
    expect(
      find.text('Could not download template. Please try again.'),
      findsOneWidget,
    );
    // No success snackbar
    expect(find.textContaining('Template downloaded'), findsNothing);
  });

  testWidgets('Sample ZIP save failure shows friendly error message', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen(fileSaver: _failingSaver)));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('download_sample_btn')));
    });
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Could not download sample ZIP. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sample downloaded'), findsNothing);
  });
}
