import 'package:eagleflow/features/products/domain/product.dart';

class BulkImportRow {
  final int rowIndex;
  final Product? product;
  final List<String> errors;
  final List<int>? imageBytes;
  final String? imageStatus;

  const BulkImportRow({
    required this.rowIndex,
    this.product,
    this.errors = const [],
    this.imageBytes,
    this.imageStatus,
  });

  bool get isValid => errors.isEmpty && product != null;

  BulkImportRow copyWith({
    int? rowIndex,
    Product? product,
    List<String>? errors,
    List<int>? imageBytes,
    String? imageStatus,
  }) {
    return BulkImportRow(
      rowIndex: rowIndex ?? this.rowIndex,
      product: product ?? this.product,
      errors: errors ?? this.errors,
      imageBytes: imageBytes ?? this.imageBytes,
      imageStatus: imageStatus ?? this.imageStatus,
    );
  }
}

class BulkImportPreview {
  final List<BulkImportRow> rows;
  final int totalRows;
  final int validCount;
  final int errorCount;
  final String? globalError;

  const BulkImportPreview({
    required this.rows,
    required this.totalRows,
    required this.validCount,
    required this.errorCount,
    this.globalError,
  });

  bool get canImport =>
      errorCount == 0 && validCount > 0 && globalError == null;
}

class BulkImportResult {
  final bool success;
  final String message;
  final int importedCount;

  const BulkImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
  });
}
