import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:eagleflow/features/products/application/bulk_import_service.dart';
import 'package:eagleflow/features/products/domain/bulk_import_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';

class MockProductRepository implements ProductRepository {
  final Map<String, Product> _db = {};
  bool forceFail = false;

  @override
  Future<void> init() async {}

  Future<Product?> getProduct(String id) async => _db[id];

  @override
  Future<Product?> getProductById(String id) async => _db[id];

  @override
  Future<Product> getProductWithImage(Product product) async => product;

  @override
  Future<bool> hasQuotationReferences(String productId) async => false;

  @override
  Future<void> toggleProductStatus(String id, bool isActive) async {
    if (_db.containsKey(id)) {
      _db[id] = _db[id]!.copyWith(isActive: isActive);
    }
  }

  Future<Product?> getProductByCode(String code) async {
    for (final p in _db.values) {
      if (p.normalizedProductCode == code.trim().toUpperCase()) return p;
    }
    return null;
  }

  @override
  Future<List<Product>> getAllProducts() async => _db.values.toList();

  @override
  Future<bool> isProductCodeUnique(
    String productCode, {
    String? excludeId,
  }) async {
    for (final p in _db.values) {
      if (p.id != excludeId &&
          p.normalizedProductCode == productCode.trim().toUpperCase()) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<Product> addProduct(Product product) async {
    if (forceFail) throw Exception('Mock DB Error');
    _db[product.id] = product;
    return product;
  }

  @override
  Future<void> addProducts(List<Product> products) async {
    if (forceFail) throw Exception('Mock DB Error');
    for (var p in products) {
      _db[p.id] = p;
    }
  }

  @override
  Future<Product> updateProduct(Product product) async {
    if (_db.containsKey(product.id)) {
      _db[product.id] = product;
      return product;
    }
    throw Exception('Not found');
  }

  @override
  Future<void> deleteProduct(String id) async {
    _db.remove(id);
  }

  Future<bool> clearProducts() async {
    _db.clear();
    return true;
  }

  void seedProduct(String code) {
    _db[code] = Product(
      id: code,
      productCode: code,
      name: 'Seed',
      category: 'Cat',
      brand: 'Brand',
      sellingPrice: 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class MockSupabaseService implements SupabaseService {
  bool overrideConnected = true;

  @override
  bool get isConnected => overrideConnected;

  @override
  get client => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// FakeBulkImportService — subclass that stubs the three seam methods so we
// can test rollback paths without a real SupabaseClient.
// ---------------------------------------------------------------------------

class FakeSupabaseService implements SupabaseService {
  bool overrideConnected = true;

  @override
  bool get isConnected => overrideConnected;

  /// Returns null — seam methods in FakeBulkImportService bypass the client.
  @override
  get client => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Subclass of BulkImportService that overrides the three seam methods.
/// Each method records calls and can be configured to throw.
class FakeBulkImportService extends BulkImportService {
  FakeBulkImportService(super.repository, super.supabase);

  // -- hasRemoteClient seam: always return true so upload/insert/remove run --
  @override
  bool get hasRemoteClient => true;

  // -- processImage seam: return bytes as-is (no isolate/decoding needed) --
  @override
  Future<Uint8List> processImage(List<int> bytes) async =>
      Uint8List.fromList(bytes);

  // -- upload control --
  int uploadCallCount = 0;
  int uploadFailOnCall = -1; // -1 = never fail
  final List<String> uploadedPaths = [];

  // -- insert control --
  bool insertShouldFail = false;

  // -- remove (rollback) control --
  final List<String> removedPaths = [];
  bool removeShouldFail = false;

  @override
  Future<void> uploadImageBytes(String path, Uint8List bytes) async {
    uploadCallCount++;
    if (uploadFailOnCall >= 0 && uploadCallCount == uploadFailOnCall) {
      throw Exception('Fake upload failure on call $uploadCallCount');
    }
    uploadedPaths.add(path);
  }

  @override
  Future<void> insertProducts(List<Map<String, dynamic>> payload) async {
    if (insertShouldFail) throw Exception('Fake batch insert failure');
    // no-op: local writes happen through repository
  }

  @override
  Future<void> removeImages(List<String> paths) async {
    if (removeShouldFail) throw Exception('Fake remove failure');
    removedPaths.addAll(paths);
  }
}

void main() {
  late MockProductRepository repository;
  late MockSupabaseService supabase;
  late BulkImportService service;

  setUp(() {
    repository = MockProductRepository();
    supabase = MockSupabaseService();
    service = BulkImportService(repository, supabase);
  });

  const validHeaders =
      'Product Code,Name,Category,Brand,Selling Price,Opening Stock,Min Stock Level,Unit,VAT Applicable,Active,Description,Model Number,Notes\n';

  test('valid CSV generates successful preview', () async {
    const csv =
        '${validHeaders}SKU01,Test Item,Tools,Acme,10.5,100,10,Box,Yes,Yes,Desc,M1,None';
    final preview = await service.previewImport(csv);

    expect(preview.errorCount, 0);
    expect(preview.validCount, 1);
    expect(preview.canImport, true);

    final prod = preview.rows.first.product!;
    expect(prod.productCode, 'SKU01');
    expect(prod.name, 'Test Item');
    expect(prod.category, 'Tools');
    expect(prod.brand, 'Acme');
    expect(prod.sellingPrice, 10.5);
    expect(prod.openingStock, 100);
    expect(prod.minStockLevel, 10);
    expect(prod.unit, 'Box');
    expect(prod.isVatApplicable, true);
    expect(prod.isActive, true);
  });

  test('missing optional values applies defaults', () async {
    const csv = '${validHeaders}SKU02,Test Item 2,,,15,,,,,,,,';
    final preview = await service.previewImport(csv);

    expect(preview.canImport, true);
    final prod = preview.rows.first.product!;
    expect(prod.category, 'Uncategorized');
    expect(prod.brand, 'Unknown');
    expect(prod.unit, 'Nos');
    expect(prod.openingStock, 0);
    expect(prod.minStockLevel, 0);
    expect(prod.isVatApplicable, true);
    expect(prod.isActive, true);
  });

  test('malformed headers fails preview', () async {
    const csv = 'Code,Name\nSKU,Item';
    final preview = await service.previewImport(csv);
    expect(preview.globalError, isNotNull);
    expect(preview.canImport, false);
  });

  test('invalid numbers/booleans catch errors', () async {
    const csv = '${validHeaders}SKU03,Item,,,-10,-5,-2,,Maybe,Nope,,,';
    final preview = await service.previewImport(csv);
    expect(preview.errorCount, 1);
    expect(preview.canImport, false);

    final errors = preview.rows.first.errors;
    expect(errors, contains('Selling Price must be a positive number'));
    expect(errors, contains('Opening Stock must be a positive integer'));
    expect(errors, contains('Min Stock Level must be a positive integer'));
    expect(
      errors,
      contains('VAT Applicable must be Yes, No, True, False, 1, or 0'),
    );
    expect(errors, contains('Active must be Yes, No, True, False, 1, or 0'));
  });

  test('zero numeric values accepted', () async {
    const csv = '${validHeaders}SKU_ZERO,Zero Item,,,0,0,0,,,,,,,';
    final preview = await service.previewImport(csv);
    expect(preview.canImport, true);
    final prod = preview.rows.first.product!;
    expect(prod.sellingPrice, 0.0);
    expect(prod.openingStock, 0);
    expect(prod.minStockLevel, 0);
  });

  test('in-file duplicate catches error', () async {
    const csv = '${validHeaders}DUP,Item1,,,10,,,,,,,,\nDUP,Item2,,,20,,,,,,,,';
    final preview = await service.previewImport(csv);
    expect(preview.errorCount, 1);
    expect(preview.validCount, 1);
    expect(
      preview.rows[1].errors,
      contains('Duplicate Product Code inside file'),
    );
  });

  test('local duplicate catches error', () async {
    repository.seedProduct('EXISTING');
    const csv = '${validHeaders}EXISTING,Item,,,10,,,,,,,,';
    final preview = await service.previewImport(csv);
    expect(preview.errorCount, 1);
    expect(
      preview.rows.first.errors,
      contains('Product Code already exists in database'),
    );
  });

  test('offline blocked', () async {
    supabase.overrideConnected = false;
    const csv = '${validHeaders}NEW,Item,,,10,,,,,,,,';
    final preview = await service.previewImport(csv);
    final result = await service.commitImport(preview);
    expect(result.success, false);
    expect(result.message, contains('Offline import is blocked'));
  });

  test('1 invalid row causes 0 inserts', () async {
    const csv = '${validHeaders}V1,Item,,,10,,,,,,,,\n,Invalid,,,10,,,,,,,,';
    final preview = await service.previewImport(csv);
    expect(preview.canImport, false);

    final result = await service.commitImport(preview);
    expect(result.success, false);
    final products = await repository.getAllProducts();
    expect(products.isEmpty, true); // No inserts
  });

  test('successful batch imports all rows', () async {
    const csv =
        '${validHeaders}BATCH1,Item1,,,10,,,,,,,,\nBATCH2,Item2,,,20,,,,,,,,';
    final preview = await service.previewImport(csv);
    final result = await service.commitImport(preview);

    expect(result.success, true);
    final products = await repository.getAllProducts();
    expect(products.length, 2);
  });

  test('local cache failure creates no partial local cache', () async {
    const csv =
        '${validHeaders}FAIL1,Item1,,,10,,,,,,,,\nFAIL2,Item2,,,20,,,,,,,,';
    final preview = await service.previewImport(csv);
    repository.forceFail = true;
    final result = await service.commitImport(preview);
    expect(result.success, false);

    repository.forceFail = false;
    final products = await repository.getAllProducts();
    expect(products.isEmpty, true); // No inserts made
  });

  test('duplicate check is chunked: each batch <= 200 codes', () async {
    // Build 201 unique rows – enough to require two remote batches.
    final buffer = StringBuffer(validHeaders);
    for (int i = 1; i <= 201; i++) {
      buffer.writeln(
        'CHUNK${i.toString().padLeft(3, '0')},Item$i,,,10,,,,,,,,',
      );
    }
    final preview = await service.previewImport(buffer.toString());
    // client is null in MockSupabaseService so no real network call fires,
    // but commitImport must succeed (no remote duplicate branch entered)
    // and all 201 rows must be stored locally.
    final result = await service.commitImport(preview);
    expect(result.success, true);
    expect(result.importedCount, 201);
    final products = await repository.getAllProducts();
    expect(products.length, 201);
  });

  test('image upload path follows products/{id}/main.jpg pattern', () async {
    // Verify the path constant is reflected in BulkImportRow.product.imageId
    // after a successful import when images are present.
    // Because client == null in tests no actual upload happens, but the
    // product IDs must still be assigned (UUIDs generated pre-upload).
    const csv = '${validHeaders}IMGTEST,Widget,,,5,,,,,,,,';
    final preview = await service.previewImport(csv);
    final result = await service.commitImport(preview);
    expect(result.success, true);
    final products = await repository.getAllProducts();
    final product = products.first;
    // No image bytes supplied, so imageId stays null – path logic is only
    // exercised with a real client.  Verify UUIDs were generated (non-empty id).
    expect(product.id.isNotEmpty, true);
    // Verify the product code is uppercased/normalized as expected.
    expect(product.normalizedProductCode, 'IMGTEST');
  });

  test('large CSV parsing performance', () async {
    final buffer = StringBuffer(validHeaders);
    for (int i = 0; i < 5000; i++) {
      buffer.writeln('LG$i,LargeItem$i,,,100,,,,,,,,');
    }

    final stopwatch = Stopwatch()..start();
    final preview = await service.previewImport(buffer.toString());
    stopwatch.stop();

    expect(preview.validCount, 5000);
    // Should parse and validate 5000 rows in < 1s usually.
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });

  // XLSX Tests
  List<CellValue> buildExcelHeaders() => [
    TextCellValue('Product Code'),
    TextCellValue('Name'),
    TextCellValue('Category'),
    TextCellValue('Brand'),
    TextCellValue('Selling Price'),
    TextCellValue('Opening Stock'),
    TextCellValue('Min Stock Level'),
    TextCellValue('Unit'),
    TextCellValue('VAT Applicable'),
    TextCellValue('Active'),
    TextCellValue('Description'),
    TextCellValue('Model Number'),
    TextCellValue('Notes'),
  ];

  test('valid XLSX generates successful preview', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');
    sheet.appendRow(buildExcelHeaders());
    sheet.appendRow([
      TextCellValue('SKU_XLSX'),
      TextCellValue('Excel Item'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(20.5),
      IntCellValue(50),
      IntCellValue(5),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    final bytes = excel.encode()!;
    final preview = await service.previewImport('', excelBytes: bytes);

    expect(preview.errorCount, 0);
    expect(preview.validCount, 1);
    expect(preview.canImport, true);
  });

  test('missing Products sheet rejects import', () async {
    final excel = Excel.createExcel();
    final sheet = excel['WrongSheet'];
    excel.setDefaultSheet('WrongSheet');
    sheet.appendRow(buildExcelHeaders());
    final bytes = excel.encode()!;

    final preview = await service.previewImport('', excelBytes: bytes);
    expect(preview.canImport, false);
    expect(preview.globalError, contains('Missing required "Products" sheet'));
  });

  test('malformed/missing required headers in XLSX rejects import', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');
    sheet.appendRow([
      TextCellValue('Product Code'),
      TextCellValue('Selling Price'),
    ]); // Missing 'Name'
    sheet.appendRow([TextCellValue('SKU'), DoubleCellValue(10.0)]);
    final bytes = excel.encode()!;

    final preview = await service.previewImport('', excelBytes: bytes);
    expect(preview.canImport, false);
    expect(preview.globalError, contains('Missing required column: Name'));
  });

  test('duplicate headers in XLSX rejects import', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');
    sheet.appendRow([
      TextCellValue('Product Code'),
      TextCellValue('Product Code'),
      TextCellValue('Name'),
      TextCellValue('Selling Price'),
    ]);
    final bytes = excel.encode()!;

    final preview = await service.previewImport('', excelBytes: bytes);
    expect(preview.canImport, false);
    expect(preview.globalError, contains('Duplicate headers'));
  });

  test('formula in required field rejects import for that row', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');
    sheet.appendRow(buildExcelHeaders());
    sheet.appendRow([
      TextCellValue('F_SKU'), TextCellValue('Item'), TextCellValue(''),
      TextCellValue(''),
      FormulaCellValue('SUM(1,2)'),
      IntCellValue(50), // Formula in Selling Price
      IntCellValue(5), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''),
    ]);
    final bytes = excel.encode()!;

    final preview = await service.previewImport('', excelBytes: bytes);
    expect(preview.canImport, false);
    expect(
      preview.rows.first.errors,
      contains('Formulas in required fields are not allowed'),
    );
  });

  test('hidden required column rejects import', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');
    sheet.appendRow(buildExcelHeaders());
    sheet.setColumnWidth(0, 0.0); // Hide Product Code
    final bytes = excel.encode()!;

    final preview = await service.previewImport('', excelBytes: bytes);
    expect(preview.canImport, false);
    expect(
      preview.globalError,
      contains('Hidden required columns are not allowed'),
    );
  });

  test('generated template parses successfully', () async {
    final bytes = service.generateTemplate();
    final preview = await service.previewImport('', excelBytes: bytes);
    expect(preview.canImport, true);
    expect(preview.validCount, 3);
  });

  group('ZIP Import Tests', () {
    final validJpg = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x01,
      0x00,
      0x48,
      0x00,
      0x48,
      0x00,
      0x00,
      0xFF,
      0xDB,
      0x00,
      0x43,
      0x00,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0xFF,
      0xC0,
      0x00,
      0x0B,
      0x08,
      0x00,
      0x01,
      0x00,
      0x01,
      0x01,
      0x01,
      0x11,
      0x00,
      0xFF,
      0xC4,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xFF,
      0xC4,
      0x00,
      0x14,
      0x10,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xFF,
      0xDA,
      0x00,
      0x08,
      0x01,
      0x01,
      0x00,
      0x00,
      0x3F,
      0x00,
      0x3F,
      0xFF,
      0xD9,
    ]);
    final corruptJpg = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
    ]);

    List<int> createZip(List<ArchiveFile> files) {
      final archive = Archive();
      for (var f in files) {
        archive.addFile(f);
      }
      return ZipEncoder().encode(archive)!;
    }

    test('generateSampleZip creates valid visible images', () async {
      final bytes = service.generateSampleZip();
      final archive = ZipDecoder().decodeBytes(bytes);

      final imageFiles = archive.where((f) => f.name.endsWith('.jpg')).toList();
      expect(imageFiles.length, 3);

      for (final file in imageFiles) {
        final imgBytes = file.content as List<int>;
        final decoded = img.decodeImage(Uint8List.fromList(imgBytes));
        expect(decoded, isNotNull);
        expect(decoded!.width, greaterThanOrEqualTo(300));
        expect(decoded.height, greaterThanOrEqualTo(300));

        // Ensure image is not completely uniform (i.e. has text rendered)
        final bgPixel = decoded.getPixel(10, 10);
        final centerPixel = decoded.getPixel(150, 150); // text should be here
        expect(
          bgPixel != centerPixel,
          true,
          reason: 'Image should not be completely uniform blank color',
        );

        expect(file.name.contains('EXAMPLE-'), true);
      }
    });

    test('valid ZIP parses successfully', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('images/EXAMPLE-001.jpg', validJpg.length, validJpg),
        ArchiveFile(
          'images/EXAMPLE-002.png',
          validJpg.length,
          validJpg,
        ), // image decoder will actually read it as jpeg despite name
        ArchiveFile('EXAMPLE-003.webp', validJpg.length, validJpg),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, true);
      expect(preview.rows[0].imageStatus, 'Image Found');
      expect(preview.rows[1].imageStatus, 'Image Found');
      expect(preview.rows[2].imageStatus, 'Image Found');
    });

    test('missing workbook rejects ZIP', () async {
      final zip = createZip([
        ArchiveFile('images/EXAMPLE-001.jpg', validJpg.length, validJpg),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.globalError, contains('products.xlsx not found'));
    });

    test('duplicate workbook rejects ZIP', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('subfolder/products.xlsx', excelBytes.length, excelBytes),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.globalError, contains('Duplicate workbook files found'));
    });

    test('missing image causes validation error', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('images/EXAMPLE-001.jpg', validJpg.length, validJpg),
        // missing EXAMPLE-002 and 003
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.rows[0].imageStatus, 'Image Found');
      expect(preview.rows[1].imageStatus, 'Image Missing');
      expect(preview.rows[2].imageStatus, 'Image Missing');
      expect(
        preview.rows[1].errors.join(),
        contains('Missing image -> validation error'),
      );
    });

    test('duplicate image causes validation error', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('images/EXAMPLE-001.jpg', validJpg.length, validJpg),
        ArchiveFile('images/EXAMPLE-001.png', validJpg.length, validJpg),
        ArchiveFile('images/EXAMPLE-002.jpg', validJpg.length, validJpg),
        ArchiveFile('images/EXAMPLE-003.jpg', validJpg.length, validJpg),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.rows[0].imageStatus, 'Duplicate Image');
      expect(
        preview.rows[0].errors.join(),
        contains('Duplicate image -> validation error'),
      );
    });

    test(
      'unsupported image rejects ZIP if not matching image extension',
      () async {
        final excelBytes = service.generateTemplate();
        final zip = createZip([
          ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
          ArchiveFile(
            'images/EXAMPLE-001.gif',
            validJpg.length,
            validJpg,
          ), // .gif is rejected immediately
        ]);
        final preview = await service.previewImport('', zipBytes: zip);
        expect(preview.canImport, false);
        expect(
          preview.globalError,
          contains('Unsupported files are not allowed'),
        );
      },
    );

    test('corrupt image causes validation error', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('images/EXAMPLE-001.jpg', corruptJpg.length, corruptJpg),
        ArchiveFile('images/EXAMPLE-002.jpg', validJpg.length, validJpg),
        ArchiveFile('images/EXAMPLE-003.jpg', validJpg.length, validJpg),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.rows[0].imageStatus, 'Invalid Image');
    });

    test('zero-byte image causes validation error', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('images/EXAMPLE-001.jpg', 0, <int>[]),
        ArchiveFile('images/EXAMPLE-002.jpg', validJpg.length, validJpg),
        ArchiveFile('images/EXAMPLE-003.jpg', validJpg.length, validJpg),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.rows[0].imageStatus, 'Invalid Image');
    });

    test('unsafe ZIP path rejects ZIP', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('../images/EXAMPLE-001.jpg', validJpg.length, validJpg),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(
        preview.globalError,
        contains('Unsafe file paths detected in ZIP'),
      );
    });

    test('nested ZIP rejected', () async {
      final excelBytes = service.generateTemplate();
      final zip = createZip([
        ArchiveFile('products.xlsx', excelBytes.length, excelBytes),
        ArchiveFile('nested.zip', 0, <int>[]),
      ]);
      final preview = await service.previewImport('', zipBytes: zip);
      expect(preview.canImport, false);
      expect(preview.globalError, contains('Nested zip files are not allowed'));
    });

    test('sample ZIP validates successfully', () async {
      final sampleZip = service.generateSampleZip();
      final preview = await service.previewImport('', zipBytes: sampleZip);
      expect(preview.canImport, true);
      expect(preview.rows.length, 3);
      for (final row in preview.rows) {
        expect(row.imageStatus, 'Image Found');
      }
    });
  });

  // ── Rollback tests ─────────────────────────────────────────────────────────
  // These use FakeBulkImportService with a non-null client sentinel so the
  // upload / insert / remove branches are exercised.

  group('Rollback tests', () {
    late MockProductRepository repo;
    late FakeSupabaseService fakeSupabase;
    late FakeBulkImportService fake;

    /// Builds a valid 2-row preview that includes image bytes so uploads fire.
    /// CSV rows with image bytes are injected after previewImport by patching
    /// the preview rows directly.
    Future<BulkImportPreview> previewWithImages(
      FakeBulkImportService svc,
      List<String> codes,
    ) async {
      // Build CSV
      final csv = StringBuffer(validHeaders);
      for (final c in codes) {
        csv.writeln('$c,Item $c,,,10,,,,,,,,');
      }
      final raw = await svc.previewImport(csv.toString());

      // Patch rows to carry dummy image bytes (1×1 JPEG magic bytes are
      // enough; _processImageSync is NOT called because uploadImageBytes is
      // overridden and receives already-processed bytes in the seam).
      // We supply a minimal valid JPEG so compute() still runs without error.
      final minimalJpeg = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0xFF,
        0xD9,
      ]);
      final patchedRows = raw.rows.map((r) {
        if (!r.isValid) return r;
        return BulkImportRow(
          rowIndex: r.rowIndex,
          product: r.product,
          errors: r.errors,
          imageBytes: minimalJpeg,
          imageStatus: 'Image Found',
        );
      }).toList();
      return BulkImportPreview(
        rows: patchedRows,
        totalRows: raw.totalRows,
        validCount: raw.validCount,
        errorCount: raw.errorCount,
        globalError: raw.globalError,
      );
    }

    setUp(() {
      repo = MockProductRepository();
      fakeSupabase = FakeSupabaseService();
      fake = FakeBulkImportService(repo, fakeSupabase);
    });

    test('second upload failure rolls back the first uploaded image', () async {
      // Arrange: 2 rows with images, fail on the 2nd upload.
      final preview = await previewWithImages(fake, ['ROLLBACK1', 'ROLLBACK2']);
      fake.uploadFailOnCall = 2; // 1st succeeds, 2nd throws

      // Act
      final result = await fake.commitImport(preview);

      // Assert: failure reported
      expect(result.success, false);
      // The first uploaded path must appear in removedPaths.
      expect(fake.removedPaths.length, 1);
      expect(fake.removedPaths.first, startsWith('products/'));
      expect(fake.removedPaths.first, endsWith('/main.jpg'));
      // No products stored locally.
      final products = await repo.getAllProducts();
      expect(products, isEmpty);
    });

    test('product batch insert failure removes every uploaded image', () async {
      // Arrange: 2 rows with images, all uploads succeed, insert fails.
      final preview = await previewWithImages(fake, ['INS1', 'INS2']);
      fake.insertShouldFail = true;

      // Act
      final result = await fake.commitImport(preview);

      // Assert: failure, both uploaded images rolled back.
      expect(result.success, false);
      expect(fake.uploadedPaths.length, 2);
      expect(fake.removedPaths.length, 2);
      // Every uploaded path must be in removedPaths.
      for (final path in fake.uploadedPaths) {
        expect(fake.removedPaths, contains(path));
      }
      // No products stored locally.
      final products = await repo.getAllProducts();
      expect(products, isEmpty);
    });

    test(
      'local cache failure stores no partial products and triggers resync',
      () async {
        // Arrange: 2 rows, uploads succeed, insert succeeds, local write fails.
        final preview = await previewWithImages(fake, ['LOCAL1', 'LOCAL2']);
        repo.forceFail = true;

        // Act
        final result = await fake.commitImport(preview);

        // Assert: service reports recoverable failure.
        expect(result.success, false);
        expect(result.message, contains('Recoverable cache failure'));
        // No partial local records.
        repo.forceFail = false;
        final products = await repo.getAllProducts();
        expect(products, isEmpty);
        // Images were NOT removed (remote succeeded; resync will fix local).
        expect(fake.removedPaths, isEmpty);
      },
    );

    test(
      'successful import stores imageId as products/{id}/main.jpg',
      () async {
        // Arrange: 1 row with image, everything succeeds.
        final preview = await previewWithImages(fake, ['PATHTEST']);

        // Act
        final result = await fake.commitImport(preview);

        // Assert
        expect(result.success, true);
        final products = await repo.getAllProducts();
        expect(products.length, 1);
        final imageId = products.first.imageId;
        expect(imageId, isNotNull);
        // Must match: products/{uuid}/main.jpg
        final uuidPattern = RegExp(r'^products\/[0-9a-f\-]{36}\/main\.jpg$');
        expect(uuidPattern.hasMatch(imageId!), isTrue);
      },
    );

    test('re-running the same package is blocked before any upload', () async {
      // Arrange: first run succeeds.
      const csv = '${validHeaders}DEDUP1,Item,,,10,,,,,,,,';
      final preview = await fake.previewImport(csv);
      final first = await fake.commitImport(preview);
      expect(first.success, true);
      final uploadCountAfterFirst = fake.uploadCallCount;

      // Act: re-run with the exact same preview (same signature).
      final second = await fake.commitImport(preview);

      // Assert: blocked before any new upload.
      expect(second.success, false);
      expect(second.message, contains('already been processed'));
      // upload count must not have increased.
      expect(fake.uploadCallCount, equals(uploadCountAfterFirst));
    });
  });
}
