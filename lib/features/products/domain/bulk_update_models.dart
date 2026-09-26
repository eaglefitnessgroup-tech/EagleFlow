import 'product_condition.dart';

class ProductUpdatePatch {
  final String? productName;
  final String? category;
  final String? brand;
  final ProductCondition? condition;
  final double? sellingPrice;
  final String? unit;
  final int? minStockLevel;
  final String? description;
  final bool? vatApplicable;
  final bool? isActive;

  const ProductUpdatePatch({
    this.productName,
    this.category,
    this.brand,
    this.condition,
    this.sellingPrice,
    this.unit,
    this.minStockLevel,
    this.description,
    this.vatApplicable,
    this.isActive,
  });

  bool get isEmpty =>
      productName == null &&
      category == null &&
      brand == null &&
      condition == null &&
      sellingPrice == null &&
      unit == null &&
      minStockLevel == null &&
      description == null &&
      vatApplicable == null &&
      isActive == null;

  bool get hasChanges => !isEmpty;

  List<String> get changedFieldNames => [
    if (productName != null) 'productName',
    if (category != null) 'category',
    if (brand != null) 'brand',
    if (condition != null) 'condition',
    if (sellingPrice != null) 'sellingPrice',
    if (unit != null) 'unit',
    if (minStockLevel != null) 'minStockLevel',
    if (description != null) 'description',
    if (vatApplicable != null) 'vatApplicable',
    if (isActive != null) 'isActive',
  ];
}

class BulkProductUpdateChange {
  final String fieldKey;
  final String displayLabel;
  final Object? oldValue;
  final Object? newValue;

  const BulkProductUpdateChange({
    required this.fieldKey,
    required this.displayLabel,
    required this.oldValue,
    required this.newValue,
  });
}

enum BulkProductUpdateRowStatus {
  valid,
  unknownProduct,
  duplicateCode,
  invalid,
  noChanges,
}

class BulkProductUpdatePreviewRow {
  final int sourceRowNumber;
  final String originalProductCode;
  final String normalizedProductCode;
  final String? matchedProductId;
  final ProductUpdatePatch patch;
  final List<BulkProductUpdateChange> changes;
  final BulkProductUpdateRowStatus status;
  final String? validationReason;

  const BulkProductUpdatePreviewRow({
    required this.sourceRowNumber,
    required this.originalProductCode,
    required this.normalizedProductCode,
    required this.patch,
    required this.changes,
    required this.status,
    this.matchedProductId,
    this.validationReason,
  });
}

enum BulkProductUpdateRowResultStatus { succeeded, skipped, failed }

class BulkProductUpdateRowResult {
  final int sourceRowNumber;
  final String productCode;
  final BulkProductUpdateRowResultStatus status;
  final String? reason;

  const BulkProductUpdateRowResult({
    required this.sourceRowNumber,
    required this.productCode,
    required this.status,
    this.reason,
  });
}

class BulkProductUpdateResult {
  final List<BulkProductUpdateRowResult> rowResults;

  const BulkProductUpdateResult({required this.rowResults});

  int get succeeded => _count(BulkProductUpdateRowResultStatus.succeeded);
  int get skipped => _count(BulkProductUpdateRowResultStatus.skipped);
  int get failed => _count(BulkProductUpdateRowResultStatus.failed);

  int _count(BulkProductUpdateRowResultStatus status) =>
      rowResults.where((result) => result.status == status).length;
}
