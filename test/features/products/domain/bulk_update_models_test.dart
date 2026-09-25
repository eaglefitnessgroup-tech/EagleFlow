import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductUpdatePatch', () {
    test('empty patch reports no changes', () {
      const patch = ProductUpdatePatch();

      expect(patch.isEmpty, isTrue);
      expect(patch.hasChanges, isFalse);
      expect(patch.changedFieldNames, isEmpty);
    });

    test('one-field patch reports changes', () {
      const patch = ProductUpdatePatch(productName: 'Updated product');

      expect(patch.isEmpty, isFalse);
      expect(patch.hasChanges, isTrue);
      expect(patch.changedFieldNames, ['productName']);
    });

    test('false is treated as a real value', () {
      const patch = ProductUpdatePatch(
        vatApplicable: false,
        isActive: false,
      );

      expect(patch.hasChanges, isTrue);
      expect(patch.changedFieldNames, ['vatApplicable', 'isActive']);
    });

    test('zero selling price is treated as a real value', () {
      const patch = ProductUpdatePatch(sellingPrice: 0);

      expect(patch.hasChanges, isTrue);
      expect(patch.changedFieldNames, ['sellingPrice']);
    });

    test('zero minimum stock is treated as a real value', () {
      const patch = ProductUpdatePatch(minStockLevel: 0);

      expect(patch.hasChanges, isTrue);
      expect(patch.changedFieldNames, ['minStockLevel']);
    });

    test('excluded fields are not exposed by ProductUpdatePatch', () {
      const dynamic patch = ProductUpdatePatch();

      expect(() => patch.productCode, throwsNoSuchMethodError);
      expect(() => patch.openingStock, throwsNoSuchMethodError);
      expect(() => patch.imageId, throwsNoSuchMethodError);
      expect(() => patch.imageBytes, throwsNoSuchMethodError);
      expect(() => patch.reservedStock, throwsNoSuchMethodError);
    });
  });

  test('preview row preserves row, code, match, change, and status metadata', () {
    const patch = ProductUpdatePatch(productName: 'New name');
    const change = BulkProductUpdateChange(
      fieldKey: 'productName',
      displayLabel: 'Product Name',
      oldValue: 'Old name',
      newValue: 'New name',
    );
    const row = BulkProductUpdatePreviewRow(
      sourceRowNumber: 7,
      originalProductCode: ' sku-001 ',
      normalizedProductCode: 'SKU-001',
      matchedProductId: 'product-id',
      patch: patch,
      changes: [change],
      status: BulkProductUpdateRowStatus.valid,
    );

    expect(row.sourceRowNumber, 7);
    expect(row.originalProductCode, ' sku-001 ');
    expect(row.normalizedProductCode, 'SKU-001');
    expect(row.matchedProductId, 'product-id');
    expect(row.patch, same(patch));
    expect(row.changes, [same(change)]);
    expect(row.status, BulkProductUpdateRowStatus.valid);
    expect(row.validationReason, isNull);
  });

  test('result derives summary counts and preserves row reasons', () {
    const result = BulkProductUpdateResult(
      rowResults: [
        BulkProductUpdateRowResult(
          sourceRowNumber: 2,
          productCode: 'SKU-001',
          status: BulkProductUpdateRowResultStatus.succeeded,
        ),
        BulkProductUpdateRowResult(
          sourceRowNumber: 3,
          productCode: 'SKU-404',
          status: BulkProductUpdateRowResultStatus.skipped,
          reason: 'Unknown product',
        ),
        BulkProductUpdateRowResult(
          sourceRowNumber: 4,
          productCode: 'SKU-002',
          status: BulkProductUpdateRowResultStatus.failed,
          reason: 'Update failed',
        ),
      ],
    );

    expect(result.succeeded, 1);
    expect(result.skipped, 1);
    expect(result.failed, 1);
    expect(result.rowResults[1].reason, 'Unknown product');
    expect(result.rowResults[2].reason, 'Update failed');
  });
}
