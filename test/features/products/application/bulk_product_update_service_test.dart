import 'package:eagleflow/features/products/application/bulk_product_update_service.dart';
import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BulkProductUpdateService service;
  late Product existingProduct;

  setUp(() {
    service = BulkProductUpdateService();
    existingProduct = Product(
      id: 'product-1',
      productCode: 'SKU-001',
      name: 'Original name',
      category: 'Original category',
      brand: 'Original brand',
      condition: ProductCondition.used,
      sellingPrice: 25,
      unit: 'Nos',
      minStockLevel: 7,
      description: 'Original description',
      isVatApplicable: true,
      isActive: true,
      openingStock: 15,
      imageId: 'existing-image',
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
    );
  });

  List<BulkProductUpdatePreviewRow> previewCsv(String data) {
    return service.previewCsv(data, currentProducts: [existingProduct]);
  }

  List<int> workbookBytes(
    List<CellValue> headers,
    List<List<CellValue?>> rows, {
    void Function(Sheet sheet)? configure,
  }) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Products'];
    workbook.setDefaultSheet('Products');
    sheet.appendRow(headers);
    for (final row in rows) {
      sheet.appendRow(row);
    }
    configure?.call(sheet);
    return workbook.encode()!;
  }

  test('Product Code plus one update column works', () {
    final rows = previewCsv(
      '  product code  ,PRODUCT NAME\n sku-001 ,Updated name',
    );

    expect(rows, hasLength(1));
    expect(rows.single.status, BulkProductUpdateRowStatus.valid);
    expect(rows.single.normalizedProductCode, 'SKU-001');
    expect(rows.single.matchedProductId, 'product-1');
    expect(rows.single.patch.productName, 'Updated name');
    expect(rows.single.changes.single.fieldKey, 'productName');
  });

  test('Product Code plus multiple update columns works', () {
    final row = previewCsv(
      'Product Code,Product Name,Category,Brand,Unit\n'
      'SKU-001,Updated name,Updated category,Updated brand,Box',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.productName, 'Updated name');
    expect(row.patch.category, 'Updated category');
    expect(row.patch.brand, 'Updated brand');
    expect(row.patch.unit, 'Box');
    expect(row.changes, hasLength(4));
  });

  test('missing optional columns mean no change', () {
    final row = previewCsv(
      'Product Code,Product Name\nSKU-001,Updated name',
    ).single;

    expect(row.patch.changedFieldNames, ['productName']);
    expect(row.patch.category, isNull);
    expect(row.patch.sellingPrice, isNull);
    expect(row.patch.isActive, isNull);
    expect(row.patch.condition, isNull);
  });

  test('Condition accepts all four canonical display labels', () {
    const cases = {
      'New': ProductCondition.newProduct,
      'Used': ProductCondition.used,
      'Refurbished': ProductCondition.refurbished,
      'Display': ProductCondition.display,
    };

    for (final entry in cases.entries) {
      final current = existingProduct.copyWith(
        condition: entry.value == ProductCondition.used
            ? ProductCondition.display
            : ProductCondition.used,
      );
      final row = service.previewCsv(
        'Product Code,Condition\nSKU-001,${entry.key}',
        currentProducts: [current],
      ).single;

      expect(row.status, BulkProductUpdateRowStatus.valid);
      expect(row.patch.condition, entry.value);
    }
  });

  test('Condition parsing is case-insensitive and trims whitespace', () {
    final row = previewCsv(
      'Product Code,Condition\nSKU-001,  rEfUrBiShEd  ',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.condition, ProductCondition.refurbished);
  });

  test('invalid Condition produces a clear invalid-row reason', () {
    final row = previewCsv(
      'Product Code,Condition\nSKU-001,Damaged',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.invalid);
    expect(
      row.validationReason,
      contains('Invalid Condition. Use New, Used, Refurbished, or Display.'),
    );
    expect(row.patch.isEmpty, isTrue);
  });

  test('blank Condition means no change', () {
    final rows = previewCsv('Product Code,Condition\nSKU-001,   ');

    expect(rows.single.status, BulkProductUpdateRowStatus.noChanges);
    expect(rows.single.patch.condition, isNull);
  });

  test('same Condition is noChanges', () {
    final row = previewCsv('Product Code,Condition\nSKU-001,Used').single;

    expect(row.status, BulkProductUpdateRowStatus.noChanges);
    expect(row.changes, isEmpty);
  });

  test('changed Condition produces exactly one typed change', () {
    final row = previewCsv(
      'Product Code,Condition\nSKU-001,Refurbished',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.changedFieldNames, ['condition']);
    expect(row.changes, hasLength(1));
    expect(row.changes.single.fieldKey, 'condition');
    expect(row.changes.single.displayLabel, 'Condition');
    expect(row.changes.single.oldValue, ProductCondition.used);
    expect(row.changes.single.newValue, ProductCondition.refurbished);
  });

  test('minimal XLSX with Product Code and Condition is accepted', () {
    final bytes = workbookBytes(
      [TextCellValue('Product Code'), TextCellValue('Condition')],
      [
        [TextCellValue('SKU-001'), TextCellValue('Display')],
      ],
    );

    final row = service
        .previewExcel(bytes, currentProducts: [existingProduct])
        .single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.condition, ProductCondition.display);
  });

  test('blank and whitespace-only cells mean no change', () {
    final rows = previewCsv('Product Code,Product Name,Category\nSKU-001,   ,');

    expect(rows.single.status, BulkProductUpdateRowStatus.noChanges);
    expect(rows.single.patch.isEmpty, isTrue);
    expect(rows.single.changes, isEmpty);
  });

  test('Selling Price zero is valid', () {
    final row = previewCsv('Product Code,Selling Price\nSKU-001,0').single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.sellingPrice, 0);
    expect(row.changes.single.newValue, 0);
  });

  test('boolean false values are valid', () {
    final row = previewCsv(
      'Product Code,VAT Applicable,Active Product\nSKU-001,No,0',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.vatApplicable, isFalse);
    expect(row.patch.isActive, isFalse);
  });

  test('Min Stock Level zero is valid', () {
    final row = previewCsv('Product Code,Min Stock Level\nSKU-001,0').single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.minStockLevel, 0);
  });

  test('unknown Product Code is reported without a patch', () {
    final row = previewCsv(
      'Product Code,Product Name\nUNKNOWN,Updated name',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.unknownProduct);
    expect(row.matchedProductId, isNull);
    expect(row.patch.isEmpty, isTrue);
    expect(row.validationReason, contains('Unknown Product Code'));
  });

  test('all duplicate Product Code occurrences are flagged', () {
    final rows = previewCsv(
      'Product Code,Product Name\n'
      ' sku-001 ,First update\n'
      'SKU-001,Second update',
    );

    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row.status),
      everyElement(BulkProductUpdateRowStatus.duplicateCode),
    );
    expect(rows.every((row) => row.patch.isEmpty), isTrue);
  });

  test('invalid numeric values produce an invalid row', () {
    final row = previewCsv(
      'Product Code,Selling Price,Min Stock Level\nSKU-001,NaN,2.5',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.invalid);
    expect(row.validationReason, contains('Selling Price'));
    expect(row.validationReason, contains('Min Stock Level'));
  });

  test('invalid boolean values produce an invalid row', () {
    final row = previewCsv(
      'Product Code,VAT Applicable,Active Product\nSKU-001,maybe,enabled',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.invalid);
    expect(row.validationReason, contains('VAT Applicable'));
    expect(row.validationReason, contains('Active Product'));
  });

  test('unknown header is rejected', () {
    expect(
      () => previewCsv('Product Code,Colour\nSKU-001,Blue'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unknown column: Colour'),
        ),
      ),
    );
  });

  test('forbidden Opening Stock header is rejected', () {
    expect(
      () => previewCsv('Product Code,Opening Stock\nSKU-001,99'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Forbidden column'),
        ),
      ),
    );
  });

  test('formula cells are rejected', () {
    final bytes = workbookBytes(
      [TextCellValue('Product Code'), TextCellValue('Product Name')],
      [
        [TextCellValue('SKU-001'), FormulaCellValue('"Updated name"')],
      ],
    );

    final row = service
        .previewExcel(bytes, currentProducts: [existingProduct])
        .single;

    expect(row.status, BulkProductUpdateRowStatus.invalid);
    expect(row.validationReason, contains('formulas are not allowed'));
    expect(row.patch.isEmpty, isTrue);
  });

  test('equal supplied values produce noChanges', () {
    final row = previewCsv(
      'Product Code,Product Name,Selling Price,VAT Applicable\n'
      'SKU-001,Original name,25,Yes',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.noChanges);
    expect(row.patch.isEmpty, isTrue);
    expect(row.changes, isEmpty);
  });

  test('Product Code is lookup-only and never enters the patch', () {
    final row = previewCsv(
      'Product Code,Product Name\nSKU-001,Updated name',
    ).single;
    final dynamic patch = row.patch;

    expect(row.originalProductCode, 'SKU-001');
    expect(row.patch.changedFieldNames, ['productName']);
    expect(() => patch.productCode, throwsNoSuchMethodError);
  });

  test('multiline Description is preserved exactly', () {
    const description = 'Line 1\nLine 2\nLine 3';
    final row = previewCsv(
      'Product Code,Description / Notes\nSKU-001,"$description"',
    ).single;

    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.patch.description, description);
    expect(row.changes.single.newValue, description);
  });

  test('CSV and XLSX produce equivalent previews', () {
    final csvRow = previewCsv(
      'Product Code,Selling Price,Active Product\nSKU-001,0,No',
    ).single;
    final bytes = workbookBytes(
      [
        TextCellValue('Product Code'),
        TextCellValue('Selling Price'),
        TextCellValue('Active Product'),
      ],
      [
        [TextCellValue('SKU-001'), IntCellValue(0), TextCellValue('No')],
      ],
    );
    final excelRow = service
        .previewExcel(bytes, currentProducts: [existingProduct])
        .single;

    expect(excelRow.status, csvRow.status);
    expect(excelRow.normalizedProductCode, csvRow.normalizedProductCode);
    expect(excelRow.patch.sellingPrice, csvRow.patch.sellingPrice);
    expect(excelRow.patch.isActive, csvRow.patch.isActive);
    expect(
      excelRow.changes.map((change) => change.fieldKey),
      csvRow.changes.map((change) => change.fieldKey),
    );
  });

  test('numeric Excel Product Code cell is rejected', () {
    final bytes = workbookBytes(
      [TextCellValue('Product Code'), TextCellValue('Product Name')],
      [
        [IntCellValue(123), TextCellValue('Updated name')],
      ],
    );

    final row = service
        .previewExcel(bytes, currentProducts: [existingProduct])
        .single;

    expect(row.status, BulkProductUpdateRowStatus.invalid);
    expect(row.validationReason, contains('stored as text'));
  });

  test('duplicate normalized headers are rejected', () {
    expect(
      () => previewCsv(
        'Product Code,Product Name, product name \nSKU-001,One,Two',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('Product Code requires at least one update column', () {
    expect(
      () => previewCsv('Product Code\nSKU-001'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('At least one update column'),
        ),
      ),
    );
  });

  test('merged and hidden headers are rejected', () {
    final merged = workbookBytes(
      [TextCellValue('Product Code'), TextCellValue('Product Name')],
      const [],
      configure: (sheet) => sheet.merge(
        CellIndex.indexByString('A1'),
        CellIndex.indexByString('B1'),
      ),
    );
    final hidden = workbookBytes(
      [TextCellValue('Product Code'), TextCellValue('Product Name')],
      const [],
      configure: (sheet) => sheet.setColumnWidth(1, 0),
    );

    expect(
      () => service.previewExcel(merged, currentProducts: [existingProduct]),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.previewExcel(hidden, currentProducts: [existingProduct]),
      throwsA(isA<FormatException>()),
    );
  });
}
