import 'package:eagleflow/features/products/application/bulk_product_update_service.dart';
import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BulkProductUpdateService service;
  late List<Product> products;

  setUp(() {
    service = BulkProductUpdateService();
    products = [
      Product(
        id: 'internal-id-1',
        productCode: '00123',
        name: 'First product',
        category: 'Equipment',
        brand: 'Eagle',
        condition: ProductCondition.used,
        sellingPrice: 125.75,
        unit: 'Nos',
        minStockLevel: 4,
        description: 'Line 1\nLine 2\nLine 3',
        isVatApplicable: true,
        isActive: false,
        openingStock: 99,
        notes: 'Separate internal notes',
        imageId: 'private-image-id',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
      ),
      Product(
        id: 'internal-id-2',
        productCode: 'SKU-002',
        name: 'Second product',
        category: '',
        brand: '',
        sellingPrice: 0,
        unit: '',
        minStockLevel: 0,
        description: '',
        isVatApplicable: false,
        isActive: true,
        openingStock: 12,
        createdAt: DateTime.parse('2026-02-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-02-02T00:00:00Z'),
      ),
    ];
  });

  Excel generatedWorkbook() {
    return Excel.decodeBytes(service.generateCurrentProductsWorkbook(products));
  }

  CellValue? cellValue(Sheet sheet, int column, int row) {
    return sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
        .value;
  }

  String textValue(CellValue? value) {
    expect(value, isA<TextCellValue>());
    return (value! as TextCellValue).value.toString();
  }

  test('workbook contains Products sheet', () {
    final workbook = generatedWorkbook();

    expect(workbook.tables.containsKey('Products'), isTrue);
    expect(workbook.tables.containsKey('Sheet1'), isFalse);
  });

  test('headers use the exact required order', () {
    final sheet = generatedWorkbook().tables['Products']!;
    final headers = List.generate(
      BulkProductUpdateService.currentProductExportHeaders.length,
      (column) => textValue(cellValue(sheet, column, 0)),
    );

    expect(headers, BulkProductUpdateService.currentProductExportHeaders);
  });

  test('Product Code is exported as text', () {
    final sheet = generatedWorkbook().tables['Products']!;

    expect(cellValue(sheet, 0, 1), isA<TextCellValue>());
  });

  test('leading-zero Product Code is preserved', () {
    final sheet = generatedWorkbook().tables['Products']!;

    expect(textValue(cellValue(sheet, 0, 1)), '00123');
  });

  test('Selling Price is exported as a numeric cell', () {
    final sheet = generatedWorkbook().tables['Products']!;
    final value = cellValue(sheet, 5, 1);

    expect(value, isA<DoubleCellValue>());
    expect((value! as DoubleCellValue).value, 125.75);
  });

  test('Min Stock Level is exported as a numeric cell', () {
    final sheet = generatedWorkbook().tables['Products']!;
    final value = cellValue(sheet, 7, 1);

    expect(value, isA<IntCellValue>());
    expect((value! as IntCellValue).value, 4);
  });

  test('VAT Applicable is exported as Yes or No', () {
    final sheet = generatedWorkbook().tables['Products']!;

    expect(textValue(cellValue(sheet, 9, 1)), 'Yes');
    expect(textValue(cellValue(sheet, 9, 2)), 'No');
  });

  test('Active Product is exported as Yes or No', () {
    final sheet = generatedWorkbook().tables['Products']!;

    expect(textValue(cellValue(sheet, 10, 1)), 'No');
    expect(textValue(cellValue(sheet, 10, 2)), 'Yes');
  });

  test('multiline Description is preserved exactly', () {
    final sheet = generatedWorkbook().tables['Products']!;

    expect(textValue(cellValue(sheet, 8, 1)), 'Line 1\nLine 2\nLine 3');
  });

  test('Condition is after Brand and exports display labels or blank', () {
    final sheet = generatedWorkbook().tables['Products']!;

    expect(textValue(cellValue(sheet, 3, 0)), 'Brand');
    expect(textValue(cellValue(sheet, 4, 0)), 'Condition');
    expect(textValue(cellValue(sheet, 5, 0)), 'Selling Price');
    expect(textValue(cellValue(sheet, 4, 1)), 'Used');
    final blank = cellValue(sheet, 4, 2);
    expect(blank == null || textValue(blank).isEmpty, isTrue);
  });

  test('all four Condition display labels export canonically', () {
    final conditions = ProductCondition.values;
    final conditionProducts = [
      for (var index = 0; index < conditions.length; index++)
        Product(
          id: 'condition-$index',
          productCode: 'COND-$index',
          name: 'Condition product $index',
          category: 'Equipment',
          brand: 'Eagle',
          condition: conditions[index],
          sellingPrice: 1,
          createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        ),
    ];
    final workbook = Excel.decodeBytes(
      service.generateCurrentProductsWorkbook(conditionProducts),
    );
    final sheet = workbook.tables['Products']!;

    expect(
      [
        for (var row = 1; row <= conditions.length; row++)
          textValue(cellValue(sheet, 4, row)),
      ],
      conditions.map((condition) => condition.displayLabel),
    );
  });

  test('forbidden and internal fields are absent', () {
    final sheet = generatedWorkbook().tables['Products']!;
    final headers = List.generate(
      sheet.maxColumns,
      (column) => textValue(cellValue(sheet, column, 0)),
    );

    expect(headers, isNot(contains('Opening Stock')));
    expect(headers, isNot(contains('Image')));
    expect(headers, isNot(contains('Notes')));
    expect(headers, isNot(contains('ID')));
    expect(headers, isNot(contains('Created At')));
    expect(headers, isNot(contains('Updated At')));
    expect(sheet.maxColumns, 11);
  });

  test('exported workbook parses without header errors', () {
    final bytes = service.generateCurrentProductsWorkbook(products);

    final preview = service.previewExcel(bytes, currentProducts: products);

    expect(preview, hasLength(products.length));
  });

  test('unchanged exported workbook produces only noChanges rows', () {
    final bytes = service.generateCurrentProductsWorkbook(products);

    final preview = service.previewExcel(bytes, currentProducts: products);

    expect(
      preview.map((row) => row.status),
      everyElement(BulkProductUpdateRowStatus.noChanges),
    );
    expect(preview.every((row) => row.changes.isEmpty), isTrue);
  });

  test('one edited cell produces exactly one Old to New change', () {
    final workbook = generatedWorkbook();
    final sheet = workbook.tables['Products']!;
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue(
      'Edited product name',
    );

    final preview = service.previewExcel(
      workbook.encode()!,
      currentProducts: products,
    );
    final editedRow = preview.first;

    expect(editedRow.status, BulkProductUpdateRowStatus.valid);
    expect(editedRow.changes, hasLength(1));
    expect(editedRow.changes.single.fieldKey, 'productName');
    expect(editedRow.changes.single.oldValue, 'First product');
    expect(editedRow.changes.single.newValue, 'Edited product name');
    expect(preview[1].status, BulkProductUpdateRowStatus.noChanges);
  });

  test('editing only exported Condition produces exactly one change', () {
    final workbook = generatedWorkbook();
    final sheet = workbook.tables['Products']!;
    sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue(
      'Refurbished',
    );

    final preview = service.previewExcel(
      workbook.encode()!,
      currentProducts: products,
    );
    final editedRow = preview.first;

    expect(editedRow.status, BulkProductUpdateRowStatus.valid);
    expect(editedRow.patch.changedFieldNames, ['condition']);
    expect(editedRow.changes, hasLength(1));
    expect(editedRow.changes.single.oldValue, ProductCondition.used);
    expect(editedRow.changes.single.newValue, ProductCondition.refurbished);
    expect(preview[1].status, BulkProductUpdateRowStatus.noChanges);
  });

  test(
    'download helper uses the approved filename and generated bytes',
    () async {
      List<int>? savedBytes;
      String? savedFilename;

      await service.downloadCurrentProductsWorkbook(
        products,
        fileSaver: ({required bytes, required filename}) async {
          savedBytes = bytes;
          savedFilename = filename;
        },
      );

      expect(savedFilename, BulkProductUpdateService.currentProductsFilename);
      expect(savedFilename, 'EagleFlow_Product_Bulk_Update.xlsx');
      expect(savedBytes, isNotEmpty);
      expect(
        Excel.decodeBytes(savedBytes!).tables.containsKey('Products'),
        isTrue,
      );
    },
  );
}
