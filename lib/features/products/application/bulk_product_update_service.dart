import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../../../core/utils/file_download_util.dart';
import '../domain/bulk_update_models.dart';
import '../domain/product.dart';

typedef BulkProductWorkbookSaver =
    Future<void> Function({required List<int> bytes, required String filename});
typedef BulkProductFieldsUpdater =
    Future<Product> Function(String productId, ProductUpdatePatch patch);
typedef BulkProductUpdateProgress = void Function(int current, int total);

class BulkProductUpdateService {
  static const String productsSheetName = 'Products';
  static const String currentProductsFilename =
      'EagleFlow_Product_Bulk_Update.xlsx';

  static const List<String> currentProductExportHeaders = [
    'Product Code',
    'Product Name',
    'Category',
    'Brand',
    'Selling Price',
    'Unit',
    'Min Stock Level',
    'Description / Notes',
    'VAT Applicable',
    'Active Product',
  ];

  static const Map<String, String> _supportedHeaders = {
    'product code': 'Product Code',
    'product name': 'Product Name',
    'category': 'Category',
    'brand': 'Brand',
    'selling price': 'Selling Price',
    'unit': 'Unit',
    'min stock level': 'Min Stock Level',
    'description / notes': 'Description / Notes',
    'vat applicable': 'VAT Applicable',
    'active product': 'Active Product',
  };

  static const Set<String> _forbiddenHeaders = {
    'opening stock',
    'image',
    'images',
    'image id',
    'image path',
    'product image',
    'stock',
    'current stock',
    'available stock',
    'reserved stock',
    'reservation',
    'reservations',
    'new product code',
    'new sku',
    'product sku',
    'sku',
  };

  List<int> generateCurrentProductsWorkbook(List<Product> products) {
    final workbook = Excel.createExcel();
    final sheet = workbook[productsSheetName];
    workbook.setDefaultSheet(productsSheetName);
    if (workbook.tables.containsKey('Sheet1')) {
      workbook.delete('Sheet1');
    }

    sheet.appendRow(
      currentProductExportHeaders.map(TextCellValue.new).toList(),
    );
    for (final product in products) {
      sheet.appendRow([
        TextCellValue(product.productCode),
        TextCellValue(product.name),
        TextCellValue(product.category),
        TextCellValue(product.brand),
        DoubleCellValue(product.sellingPrice),
        TextCellValue(product.unit),
        IntCellValue(product.minStockLevel),
        TextCellValue(product.description),
        TextCellValue(product.isVatApplicable ? 'Yes' : 'No'),
        TextCellValue(product.isActive ? 'Yes' : 'No'),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Failed to generate current products workbook.');
    }
    return bytes;
  }

  Future<void> downloadCurrentProductsWorkbook(
    List<Product> products, {
    BulkProductWorkbookSaver? fileSaver,
  }) async {
    await (fileSaver ?? FileDownloadUtil.save)(
      bytes: generateCurrentProductsWorkbook(products),
      filename: currentProductsFilename,
    );
  }

  Future<BulkProductUpdateResult> executeUpdates({
    required List<BulkProductUpdatePreviewRow> previewRows,
    required Future<List<Product>> Function() loadFreshProducts,
    required BulkProductFieldsUpdater updateProductFields,
    BulkProductUpdateProgress? onProgress,
  }) async {
    final freshProducts = await loadFreshProducts();
    final productsById = <String, Product>{
      for (final product in freshProducts) product.id: product,
    };
    final productsByCode = <String, Product>{
      for (final product in freshProducts)
        product.normalizedProductCode: product,
    };
    final validCount = previewRows
        .where((row) => row.status == BulkProductUpdateRowStatus.valid)
        .length;
    final results = <BulkProductUpdateRowResult>[];
    var current = 0;

    for (final row in previewRows) {
      if (row.status != BulkProductUpdateRowStatus.valid) {
        results.add(
          BulkProductUpdateRowResult(
            sourceRowNumber: row.sourceRowNumber,
            productCode: row.originalProductCode.trim(),
            status: BulkProductUpdateRowResultStatus.skipped,
            reason: _skipReason(row),
          ),
        );
        continue;
      }

      current++;
      onProgress?.call(current, validCount);

      final freshProduct = row.matchedProductId == null
          ? productsByCode[row.normalizedProductCode]
          : productsById[row.matchedProductId];
      if (freshProduct == null) {
        results.add(_failedResult(row, 'Product not found'));
        continue;
      }

      if (!_previewValuesStillCurrent(row, freshProduct)) {
        results.add(
          _failedResult(
            row,
            'Product changed after preview. Review and upload again.',
          ),
        );
        continue;
      }

      try {
        await updateProductFields(freshProduct.id, row.patch);
        results.add(
          BulkProductUpdateRowResult(
            sourceRowNumber: row.sourceRowNumber,
            productCode: row.originalProductCode.trim(),
            status: BulkProductUpdateRowResultStatus.succeeded,
            reason: 'Updated successfully',
          ),
        );
      } catch (_) {
        results.add(_failedResult(row, 'Update failed'));
      }
    }

    return BulkProductUpdateResult(rowResults: results);
  }

  List<BulkProductUpdatePreviewRow> previewCsv(
    String csvData, {
    required List<Product> currentProducts,
  }) {
    final decoded = csv.decode(csvData);
    final rows = decoded
        .map(
          (row) => row
              .map(
                (value) => _RawCell(
                  value?.toString() ?? '',
                  isFormula:
                      (value?.toString().trim().startsWith('=') ?? false),
                ),
              )
              .toList(),
        )
        .toList();
    return _preparePreview(rows, currentProducts);
  }

  List<BulkProductUpdatePreviewRow> previewExcel(
    List<int> excelBytes, {
    required List<Product> currentProducts,
  }) {
    final workbook = Excel.decodeBytes(excelBytes);
    final sheet = workbook.tables[productsSheetName];
    if (sheet == null) {
      throw const FormatException('Missing required "Products" sheet.');
    }
    if (sheet.maxRows == 0 || sheet.maxColumns == 0) {
      throw const FormatException('The Products sheet is empty.');
    }

    for (final span in sheet.spannedItems) {
      final parts = span.split(':');
      if (parts.length != 2) continue;
      final start = CellIndex.indexByString(parts[0]);
      final end = CellIndex.indexByString(parts[1]);
      if (start.rowIndex == 0 || end.rowIndex == 0) {
        throw const FormatException('Merged header cells are not allowed.');
      }
    }

    for (var column = 0; column < sheet.maxColumns; column++) {
      try {
        if (sheet.getColumnWidth(column) == 0.0) {
          throw const FormatException('Hidden columns are not allowed.');
        }
      } on FormatException {
        rethrow;
      } catch (_) {
        // excel 4.0.6 throws when no explicit width exists.
      }
    }

    final rows = <List<_RawCell>>[];
    for (var rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
      final sourceRow = sheet.rows[rowIndex];
      final row = <_RawCell>[];
      for (var column = 0; column < sheet.maxColumns; column++) {
        final value = column < sourceRow.length
            ? sourceRow[column]?.value
            : null;
        row.add(_excelCell(value));
      }
      rows.add(row);
    }

    return _preparePreview(rows, currentProducts);
  }

  List<BulkProductUpdatePreviewRow> _preparePreview(
    List<List<_RawCell>> rows,
    List<Product> currentProducts,
  ) {
    if (rows.isEmpty) {
      throw const FormatException('The file is empty or missing a header row.');
    }

    final rawHeaders = rows.first;
    if (rawHeaders.isEmpty) {
      throw const FormatException('The file is missing a header row.');
    }

    final headerIndexes = <String, int>{};
    for (var index = 0; index < rawHeaders.length; index++) {
      final headerCell = rawHeaders[index];
      if (headerCell.isFormula) {
        throw const FormatException('Formula headers are not allowed.');
      }

      final normalized = _normalizeHeader(headerCell.text);
      if (normalized.isEmpty) {
        throw FormatException('Blank header at column ${index + 1}.');
      }
      if (headerIndexes.containsKey(normalized)) {
        throw FormatException(
          'Duplicate header is not allowed: ${headerCell.text.trim()}',
        );
      }
      if (_forbiddenHeaders.contains(normalized)) {
        throw FormatException(
          'Forbidden column is not allowed: ${headerCell.text.trim()}',
        );
      }
      if (!_supportedHeaders.containsKey(normalized)) {
        throw FormatException('Unknown column: ${headerCell.text.trim()}');
      }
      headerIndexes[normalized] = index;
    }

    if (!headerIndexes.containsKey('product code')) {
      throw const FormatException('Missing required column: Product Code');
    }
    if (headerIndexes.length == 1) {
      throw const FormatException(
        'At least one update column is required in addition to Product Code.',
      );
    }

    final nonEmptyRows = <_SourceRow>[];
    for (var index = 1; index < rows.length; index++) {
      final cells = rows[index];
      if (cells.every((cell) => cell.isBlank && !cell.isFormula)) continue;
      if (cells.length > rawHeaders.length &&
          cells.skip(rawHeaders.length).any((cell) => !cell.isBlank)) {
        throw FormatException(
          'Row ${index + 1} contains data without a column header.',
        );
      }
      nonEmptyRows.add(_SourceRow(index + 1, cells));
    }

    final codeIndex = headerIndexes['product code']!;
    final codeCounts = <String, int>{};
    for (final sourceRow in nonEmptyRows) {
      final codeCell = sourceRow.cellAt(codeIndex);
      if (codeCell.isFormula || codeCell.isNumeric || codeCell.isBlank) {
        continue;
      }
      final normalizedCode = _normalizeProductCode(codeCell.text);
      if (normalizedCode.isNotEmpty) {
        codeCounts.update(
          normalizedCode,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final productsByCode = <String, Product>{
      for (final product in currentProducts)
        product.normalizedProductCode: product,
    };

    return nonEmptyRows.map((sourceRow) {
      final codeCell = sourceRow.cellAt(codeIndex);
      final originalCode = codeCell.text;
      final normalizedCode = _normalizeProductCode(originalCode);
      final errors = <String>[];

      if (codeCell.isFormula) {
        errors.add('Product Code formulas are not allowed');
      } else if (codeCell.isNumeric) {
        errors.add('Product Code must be stored as text, not a numeric cell');
      } else if (codeCell.isBlank) {
        errors.add('Product Code is required');
      }

      for (final entry in headerIndexes.entries) {
        if (entry.key == 'product code') continue;
        if (sourceRow.cellAt(entry.value).isFormula) {
          errors.add(
            '${_supportedHeaders[entry.key]} formulas are not allowed',
          );
        }
      }

      final suppliedPatch = _parsePatch(sourceRow, headerIndexes, errors);
      final duplicate =
          normalizedCode.isNotEmpty && (codeCounts[normalizedCode] ?? 0) > 1;

      if (duplicate) {
        return BulkProductUpdatePreviewRow(
          sourceRowNumber: sourceRow.rowNumber,
          originalProductCode: originalCode,
          normalizedProductCode: normalizedCode,
          patch: const ProductUpdatePatch(),
          changes: const [],
          status: BulkProductUpdateRowStatus.duplicateCode,
          validationReason: 'Duplicate Product Code in uploaded file',
        );
      }

      if (errors.isNotEmpty) {
        return BulkProductUpdatePreviewRow(
          sourceRowNumber: sourceRow.rowNumber,
          originalProductCode: originalCode,
          normalizedProductCode: normalizedCode,
          patch: const ProductUpdatePatch(),
          changes: const [],
          status: BulkProductUpdateRowStatus.invalid,
          validationReason: errors.join('; '),
        );
      }

      final product = productsByCode[normalizedCode];
      if (product == null) {
        return BulkProductUpdatePreviewRow(
          sourceRowNumber: sourceRow.rowNumber,
          originalProductCode: originalCode,
          normalizedProductCode: normalizedCode,
          patch: const ProductUpdatePatch(),
          changes: const [],
          status: BulkProductUpdateRowStatus.unknownProduct,
          validationReason: 'Unknown Product Code',
        );
      }

      final comparison = _compareWithProduct(suppliedPatch, product);
      return BulkProductUpdatePreviewRow(
        sourceRowNumber: sourceRow.rowNumber,
        originalProductCode: originalCode,
        normalizedProductCode: normalizedCode,
        matchedProductId: product.id,
        patch: comparison.patch,
        changes: comparison.changes,
        status: comparison.patch.isEmpty
            ? BulkProductUpdateRowStatus.noChanges
            : BulkProductUpdateRowStatus.valid,
      );
    }).toList();
  }

  ProductUpdatePatch _parsePatch(
    _SourceRow row,
    Map<String, int> headerIndexes,
    List<String> errors,
  ) {
    String? stringValue(String header, {bool preserveWhitespace = false}) {
      final index = headerIndexes[header];
      if (index == null) return null;
      final cell = row.cellAt(index);
      if (cell.isFormula || cell.isBlank) return null;
      return preserveWhitespace ? cell.text : cell.text.trim();
    }

    double? sellingPrice;
    final priceCell = _optionalCell(row, headerIndexes, 'selling price');
    if (priceCell != null && !priceCell.isFormula && !priceCell.isBlank) {
      final value = double.tryParse(priceCell.text.trim());
      if (value == null || !value.isFinite || value < 0) {
        errors.add(
          'Selling Price must be a finite number greater than or equal to 0',
        );
      } else {
        sellingPrice = value;
      }
    }

    int? minStockLevel;
    final minStockCell = _optionalCell(row, headerIndexes, 'min stock level');
    if (minStockCell != null &&
        !minStockCell.isFormula &&
        !minStockCell.isBlank) {
      final value = double.tryParse(minStockCell.text.trim());
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value != value.truncateToDouble()) {
        errors.add(
          'Min Stock Level must be a whole number greater than or equal to 0',
        );
      } else {
        minStockLevel = value.toInt();
      }
    }

    bool? parseBoolean(String header, String label) {
      final cell = _optionalCell(row, headerIndexes, header);
      if (cell == null || cell.isFormula || cell.isBlank) return null;
      switch (cell.text.trim().toLowerCase()) {
        case 'yes':
        case 'true':
        case '1':
        case 'y':
          return true;
        case 'no':
        case 'false':
        case '0':
        case 'n':
          return false;
        default:
          errors.add('$label must be Yes, No, True, False, 1, 0, Y, or N');
          return null;
      }
    }

    return ProductUpdatePatch(
      productName: stringValue('product name'),
      category: stringValue('category'),
      brand: stringValue('brand'),
      sellingPrice: sellingPrice,
      unit: stringValue('unit'),
      minStockLevel: minStockLevel,
      description: stringValue('description / notes', preserveWhitespace: true),
      vatApplicable: parseBoolean('vat applicable', 'VAT Applicable'),
      isActive: parseBoolean('active product', 'Active Product'),
    );
  }

  _PatchComparison _compareWithProduct(
    ProductUpdatePatch supplied,
    Product product,
  ) {
    final changes = <BulkProductUpdateChange>[];

    String? productName;
    if (supplied.productName != null && supplied.productName != product.name) {
      productName = supplied.productName;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'productName',
          displayLabel: 'Product Name',
          oldValue: product.name,
          newValue: productName,
        ),
      );
    }

    String? category;
    if (supplied.category != null && supplied.category != product.category) {
      category = supplied.category;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'category',
          displayLabel: 'Category',
          oldValue: product.category,
          newValue: category,
        ),
      );
    }

    String? brand;
    if (supplied.brand != null && supplied.brand != product.brand) {
      brand = supplied.brand;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'brand',
          displayLabel: 'Brand',
          oldValue: product.brand,
          newValue: brand,
        ),
      );
    }

    double? sellingPrice;
    if (supplied.sellingPrice != null &&
        supplied.sellingPrice != product.sellingPrice) {
      sellingPrice = supplied.sellingPrice;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'sellingPrice',
          displayLabel: 'Selling Price',
          oldValue: product.sellingPrice,
          newValue: sellingPrice,
        ),
      );
    }

    String? unit;
    if (supplied.unit != null && supplied.unit != product.unit) {
      unit = supplied.unit;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'unit',
          displayLabel: 'Unit',
          oldValue: product.unit,
          newValue: unit,
        ),
      );
    }

    int? minStockLevel;
    if (supplied.minStockLevel != null &&
        supplied.minStockLevel != product.minStockLevel) {
      minStockLevel = supplied.minStockLevel;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'minStockLevel',
          displayLabel: 'Min Stock Level',
          oldValue: product.minStockLevel,
          newValue: minStockLevel,
        ),
      );
    }

    String? description;
    if (supplied.description != null &&
        supplied.description != product.description) {
      description = supplied.description;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'description',
          displayLabel: 'Description / Notes',
          oldValue: product.description,
          newValue: description,
        ),
      );
    }

    bool? vatApplicable;
    if (supplied.vatApplicable != null &&
        supplied.vatApplicable != product.isVatApplicable) {
      vatApplicable = supplied.vatApplicable;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'vatApplicable',
          displayLabel: 'VAT Applicable',
          oldValue: product.isVatApplicable,
          newValue: vatApplicable,
        ),
      );
    }

    bool? isActive;
    if (supplied.isActive != null && supplied.isActive != product.isActive) {
      isActive = supplied.isActive;
      changes.add(
        BulkProductUpdateChange(
          fieldKey: 'isActive',
          displayLabel: 'Active Product',
          oldValue: product.isActive,
          newValue: isActive,
        ),
      );
    }

    return _PatchComparison(
      ProductUpdatePatch(
        productName: productName,
        category: category,
        brand: brand,
        sellingPrice: sellingPrice,
        unit: unit,
        minStockLevel: minStockLevel,
        description: description,
        vatApplicable: vatApplicable,
        isActive: isActive,
      ),
      changes,
    );
  }

  bool _previewValuesStillCurrent(
    BulkProductUpdatePreviewRow row,
    Product product,
  ) {
    for (final change in row.changes) {
      if (_productFieldValue(product, change.fieldKey) != change.oldValue) {
        return false;
      }
    }
    return true;
  }

  Object? _productFieldValue(Product product, String fieldKey) {
    switch (fieldKey) {
      case 'productName':
        return product.name;
      case 'category':
        return product.category;
      case 'brand':
        return product.brand;
      case 'sellingPrice':
        return product.sellingPrice;
      case 'unit':
        return product.unit;
      case 'minStockLevel':
        return product.minStockLevel;
      case 'description':
        return product.description;
      case 'vatApplicable':
        return product.isVatApplicable;
      case 'isActive':
        return product.isActive;
    }
    return null;
  }

  String _skipReason(BulkProductUpdatePreviewRow row) {
    if (row.status == BulkProductUpdateRowStatus.noChanges) {
      return 'No changes';
    }
    return row.validationReason ?? 'Row is not eligible for update';
  }

  BulkProductUpdateRowResult _failedResult(
    BulkProductUpdatePreviewRow row,
    String reason,
  ) {
    return BulkProductUpdateRowResult(
      sourceRowNumber: row.sourceRowNumber,
      productCode: row.originalProductCode.trim(),
      status: BulkProductUpdateRowResultStatus.failed,
      reason: reason,
    );
  }

  _RawCell? _optionalCell(
    _SourceRow row,
    Map<String, int> headerIndexes,
    String header,
  ) {
    final index = headerIndexes[header];
    return index == null ? null : row.cellAt(index);
  }

  _RawCell _excelCell(CellValue? value) {
    if (value == null) return const _RawCell('');
    if (value is FormulaCellValue) {
      return _RawCell(value.toString(), isFormula: true);
    }
    if (value is IntCellValue) {
      return _RawCell(value.value.toString(), isNumeric: true);
    }
    if (value is DoubleCellValue) {
      return _RawCell(value.value.toString(), isNumeric: true);
    }
    if (value is BoolCellValue) {
      return _RawCell(value.value.toString());
    }
    if (value is TextCellValue) {
      return _RawCell(value.value.toString());
    }
    return _RawCell(value.toString());
  }

  String _normalizeHeader(String value) => value.trim().toLowerCase();

  String _normalizeProductCode(String value) => value.trim().toUpperCase();
}

class _RawCell {
  final String text;
  final bool isNumeric;
  final bool isFormula;

  const _RawCell(this.text, {this.isNumeric = false, this.isFormula = false});

  bool get isBlank => text.trim().isEmpty;
}

class _SourceRow {
  final int rowNumber;
  final List<_RawCell> cells;

  const _SourceRow(this.rowNumber, this.cells);

  _RawCell cellAt(int index) =>
      index < cells.length ? cells[index] : const _RawCell('');
}

class _PatchComparison {
  final ProductUpdatePatch patch;
  final List<BulkProductUpdateChange> changes;

  const _PatchComparison(this.patch, this.changes);
}
