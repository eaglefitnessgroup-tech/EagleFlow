import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:eagleflow/features/products/presentation/bulk_import_screen.dart';
import 'package:eagleflow/features/products/domain/bulk_import_models.dart';
import 'package:eagleflow/app/routes/app_routes.dart';
import 'package:eagleflow/core/guards/admin_guard.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import '../../../features/authentication/fake_auth_repository.dart';
import 'package:eagleflow/features/products/presentation/folder_picker/folder_picker.dart';
import 'package:image/image.dart' as img;

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

void _mockFolderPicker() {
  final imgImage = img.Image(width: 10, height: 10);
  img.fill(imgImage, color: img.ColorRgb8(255, 0, 0));
  final validJpg = img.encodeJpg(imgImage);

  mockFolderFilesForTesting = {
    'TEST1.jpg': validJpg,
  };
}

void _mockExcelFile(String csvContent, {String filename = 'products.csv'}) {
  mockExcelFileForTesting = {filename: utf8.encode(csvContent)};
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

    _mockFolderPicker();
    _mockExcelFile(_validCsvRow, filename: 'products.csv');
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
    SupabaseService.resetForTesting();
    mockFolderFilesForTesting = null;
    mockExcelFileForTesting = null;
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
  BulkImportScreen screen({
    FileSaver? fileSaver,
    BulkImportCommitter? commitImport,
    bool? isOnlineOverride,
  }) => BulkImportScreen(
    fileSaver: fileSaver ?? _capturingSaver,
    commitImport: commitImport,
    isOnlineOverride: isOnlineOverride,
  );

  Future<void> loginAdmin(WidgetTester tester) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(email: 'anshad@eagleflow.com',
        password: 'anshad123',
        rememberMe: false,
      );
    });
  }

  Future<void> loginSales(WidgetTester tester) async {
    await tester.runAsync(() async {
      await ServiceLocator().authController.login(email: 'ajmal@eagleflow.com',
        password: 'ajmal123',
        rememberMe: false,
      );
    });
  }

  // â”€â”€ access control â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€ initial state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  testWidgets('Shows Select Excel File and Select Image Folder buttons on initial state', (tester) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    expect(find.text('Select Excel File'), findsOneWidget);
    expect(find.text('Select Image Folder'), findsOneWidget);
  });

  testWidgets('Shows Excel Template and Sample ZIP download buttons', (
    tester,
  ) async {
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    expect(find.text('Excel Template'), findsOneWidget);
    expect(find.text('Sample Data'), findsOneWidget);
  });

  // â”€â”€ CSV parse and preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  testWidgets('Valid CSV shows Confirm Import button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    // Pick Excel file first, then image folder—preview runs automatically.
    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Import'), findsOneWidget);
  });

  testWidgets('Invalid rows disable Confirm Import button', (tester) async {
    _mockExcelFile(_invalidCsvRow, filename: 'products.csv');

    // Larger viewport so the preview table has room to render.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();

    // Confirm Import button must be disabled (invalid row present)
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('confirm_import_btn')),
    );
    expect(btn.onPressed, isNull);
  });

  // â”€â”€ summary bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  testWidgets('Summary bar shows valid/invalid counts after parse', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();

    // Summary bar should appear
    expect(find.byKey(const Key('summary_bar')), findsOneWidget);
    // Valid count — 1 row
    expect(find.text('1'), findsWidgets);
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Invalid'), findsOneWidget);
  });

  // ── image column ────────────────────────────────────────────────────────────

  testWidgets('Preview table shows Image column header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Image'), findsOneWidget);
  });

  // ── offline state ───────────────────────────────────────────────────────────

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
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();

    // Offline → button disabled (isOnline=false)
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('confirm_import_btn')),
    );
    expect(btn.onPressed, isNull);
  });

  // ── file name display ────────────────────────────────────────────────────────

  testWidgets('shows actual processed rows and completes at 100%', (
    tester,
  ) async {
    final csv = StringBuffer(
      'Product Code,Name,Category,Brand,Selling Price,Opening Stock,Min Stock Level,Unit,VAT Applicable,Active,Description,Model Number,Notes\n',
    );
    for (var i = 1; i <= 140; i++) {
      csv.writeln('PROG$i,Item $i,,,10,,,,,,,,');
    }
    _mockExcelFile(csv.toString(), filename: 'products.csv');
    final validJpg = mockFolderFilesForTesting!['TEST1.jpg']!;
    mockFolderFilesForTesting = {
      for (var i = 1; i <= 140; i++) 'PROG$i.jpg': validJpg,
    };

    final finishImport = Completer<void>();
    Future<BulkImportResult> commitImport(
      BulkImportPreview preview, {
      void Function(int processedRows, int totalRows)? onProgress,
    }) async {
      onProgress?.call(87, preview.validCount);
      await finishImport.future;
      onProgress?.call(preview.validCount, preview.validCount);
      return BulkImportResult(
        success: true,
        message: 'Successfully imported ${preview.validCount} products.',
        importedCount: preview.validCount,
      );
    }

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await loginAdmin(tester);
    await tester.pumpWidget(
      buildApp(
        screen(
          commitImport: commitImport,
          isOnlineOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_import_btn')));
    await tester.pump();

    expect(find.byKey(const Key('bulk_import_progress_bar')), findsOneWidget);
    expect(find.text('87 / 140'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);

    finishImport.complete();
    await tester.pumpAndSettle();

    expect(find.text('140 / 140'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Import Complete'), findsOneWidget);
    expect(find.byType(BulkImportScreen), findsOneWidget);
  });

  testWidgets('Picked filename is shown after selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    _mockExcelFile(_validCsvRow, filename: 'products.csv');

    await loginAdmin(tester);
    await tester.pumpWidget(buildApp(screen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_excel_btn')));
    await tester.pumpAndSettle();

    // Excel filename shown under the Excel button
    expect(find.text('products.csv'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pick_folder_btn')));
    await tester.pumpAndSettle();

    // Folder label shown under the folder button
    expect(find.text('Image Folder'), findsOneWidget);
  });

  // â”€â”€ template / sample download â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

    // No raw exception â€” friendly message shown in status area
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
      find.text('Could not download sample. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sample downloaded'), findsNothing);
  });
}
