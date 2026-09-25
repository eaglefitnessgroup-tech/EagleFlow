import 'package:eagleflow/features/products/application/bulk_product_update_service.dart';
import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BulkProductUpdateService service;

  setUp(() {
    service = BulkProductUpdateService();
  });

  test(
    'valid rows update sequentially and non-valid rows are skipped',
    () async {
      final calls = <String>[];
      var freshLoadCount = 0;
      final rows = [
        _validRow(
          row: 2,
          id: 'product-1',
          code: 'SKU-001',
          patch: const ProductUpdatePatch(productName: 'Updated one'),
          changes: const [
            BulkProductUpdateChange(
              fieldKey: 'productName',
              displayLabel: 'Product Name',
              oldValue: 'One',
              newValue: 'Updated one',
            ),
          ],
        ),
        const BulkProductUpdatePreviewRow(
          sourceRowNumber: 3,
          originalProductCode: 'SKU-002',
          normalizedProductCode: 'SKU-002',
          matchedProductId: 'product-2',
          patch: ProductUpdatePatch(),
          changes: [],
          status: BulkProductUpdateRowStatus.noChanges,
        ),
        _validRow(
          row: 4,
          id: 'product-2',
          code: 'SKU-002',
          patch: const ProductUpdatePatch(sellingPrice: 0),
          changes: const [
            BulkProductUpdateChange(
              fieldKey: 'sellingPrice',
              displayLabel: 'Selling Price',
              oldValue: 20.0,
              newValue: 0.0,
            ),
          ],
        ),
      ];

      final result = await service.executeUpdates(
        previewRows: rows,
        loadFreshProducts: () async {
          freshLoadCount++;
          return [
            _product(id: 'product-1', code: 'SKU-001', name: 'One', price: 10),
            _product(id: 'product-2', code: 'SKU-002', name: 'Two', price: 20),
          ];
        },
        updateProductFields: (id, patch) async {
          calls.add(id);
          return _product(
            id: id,
            code: id == 'product-1' ? 'SKU-001' : 'SKU-002',
            name: patch.productName ?? (id == 'product-1' ? 'One' : 'Two'),
            price: patch.sellingPrice ?? (id == 'product-1' ? 10 : 20),
          );
        },
      );

      expect(freshLoadCount, 1);
      expect(calls, ['product-1', 'product-2']);
      expect(result.succeeded, 2);
      expect(result.skipped, 1);
      expect(result.failed, 0);
      expect(result.rowResults[1].reason, 'No changes');
    },
  );

  test('one failed update does not stop a later independent row', () async {
    final calls = <String>[];
    final rows = [
      _nameRow(row: 2, id: 'product-1', code: 'SKU-001', oldName: 'One'),
      _nameRow(row: 3, id: 'product-2', code: 'SKU-002', oldName: 'Two'),
    ];

    final result = await service.executeUpdates(
      previewRows: rows,
      loadFreshProducts: () async => [
        _product(id: 'product-1', code: 'SKU-001', name: 'One'),
        _product(id: 'product-2', code: 'SKU-002', name: 'Two'),
      ],
      updateProductFields: (id, patch) async {
        calls.add(id);
        if (id == 'product-1') throw StateError('first row failed');
        return _product(id: id, code: 'SKU-002', name: patch.productName!);
      },
    );

    expect(calls, ['product-1', 'product-2']);
    expect(result.failed, 1);
    expect(result.succeeded, 1);
    expect(result.rowResults[0].reason, 'Update failed');
  });

  test(
    'changed preview field is rejected but unrelated changes are allowed',
    () async {
      final calls = <String>[];
      final rows = [
        _nameRow(row: 2, id: 'product-1', code: 'SKU-001', oldName: 'One'),
        _nameRow(row: 3, id: 'product-2', code: 'SKU-002', oldName: 'Two'),
      ];

      final result = await service.executeUpdates(
        previewRows: rows,
        loadFreshProducts: () async => [
          _product(id: 'product-1', code: 'SKU-001', name: 'Changed elsewhere'),
          _product(
            id: 'product-2',
            code: 'SKU-002',
            name: 'Two',
            brand: 'Fresh unrelated brand',
          ),
        ],
        updateProductFields: (id, patch) async {
          calls.add(id);
          return _product(id: id, code: 'SKU-002', name: patch.productName!);
        },
      );

      expect(calls, ['product-2']);
      expect(result.failed, 1);
      expect(result.succeeded, 1);
      expect(
        result.rowResults.first.reason,
        'Product changed after preview. Review and upload again.',
      );
    },
  );

  test(
    'removed product fails safely and progress covers every valid row',
    () async {
      final progress = <String>[];
      var updateCalls = 0;
      final rows = [
        _nameRow(row: 2, id: 'removed', code: 'SKU-001', oldName: 'One'),
        _nameRow(row: 3, id: 'product-2', code: 'SKU-002', oldName: 'Two'),
      ];

      final result = await service.executeUpdates(
        previewRows: rows,
        loadFreshProducts: () async => [
          _product(id: 'product-2', code: 'SKU-002', name: 'Two'),
        ],
        updateProductFields: (id, patch) async {
          updateCalls++;
          return _product(id: id, code: 'SKU-002', name: patch.productName!);
        },
        onProgress: (current, total) => progress.add('$current/$total'),
      );

      expect(updateCalls, 1);
      expect(progress, ['1/2', '2/2']);
      expect(result.failed, 1);
      expect(result.succeeded, 1);
      expect(result.rowResults.first.reason, 'Product not found');
    },
  );

  test(
    'false and zero are passed through the partial-update callback',
    () async {
      ProductUpdatePatch? receivedPatch;
      final row = _validRow(
        row: 2,
        id: 'product-1',
        code: 'SKU-001',
        patch: const ProductUpdatePatch(
          sellingPrice: 0,
          minStockLevel: 0,
          vatApplicable: false,
          isActive: false,
        ),
        changes: const [
          BulkProductUpdateChange(
            fieldKey: 'sellingPrice',
            displayLabel: 'Selling Price',
            oldValue: 10.0,
            newValue: 0.0,
          ),
          BulkProductUpdateChange(
            fieldKey: 'minStockLevel',
            displayLabel: 'Min Stock Level',
            oldValue: 5,
            newValue: 0,
          ),
          BulkProductUpdateChange(
            fieldKey: 'vatApplicable',
            displayLabel: 'VAT Applicable',
            oldValue: true,
            newValue: false,
          ),
          BulkProductUpdateChange(
            fieldKey: 'isActive',
            displayLabel: 'Active Product',
            oldValue: true,
            newValue: false,
          ),
        ],
      );

      final result = await service.executeUpdates(
        previewRows: [row],
        loadFreshProducts: () async => [
          _product(id: 'product-1', code: 'SKU-001', name: 'One'),
        ],
        updateProductFields: (id, patch) async {
          receivedPatch = patch;
          return _product(id: id, code: 'SKU-001', name: 'One');
        },
      );

      expect(result.succeeded, 1);
      expect(receivedPatch?.sellingPrice, 0);
      expect(receivedPatch?.minStockLevel, 0);
      expect(receivedPatch?.vatApplicable, isFalse);
      expect(receivedPatch?.isActive, isFalse);
    },
  );
}

BulkProductUpdatePreviewRow _nameRow({
  required int row,
  required String id,
  required String code,
  required String oldName,
}) {
  return _validRow(
    row: row,
    id: id,
    code: code,
    patch: ProductUpdatePatch(productName: 'Updated $oldName'),
    changes: [
      BulkProductUpdateChange(
        fieldKey: 'productName',
        displayLabel: 'Product Name',
        oldValue: oldName,
        newValue: 'Updated $oldName',
      ),
    ],
  );
}

BulkProductUpdatePreviewRow _validRow({
  required int row,
  required String id,
  required String code,
  required ProductUpdatePatch patch,
  required List<BulkProductUpdateChange> changes,
}) {
  return BulkProductUpdatePreviewRow(
    sourceRowNumber: row,
    originalProductCode: code,
    normalizedProductCode: code,
    matchedProductId: id,
    patch: patch,
    changes: changes,
    status: BulkProductUpdateRowStatus.valid,
  );
}

Product _product({
  required String id,
  required String code,
  required String name,
  double price = 10,
  String brand = 'Brand',
}) {
  return Product(
    id: id,
    productCode: code,
    name: name,
    category: 'Category',
    brand: brand,
    sellingPrice: price,
    unit: 'Nos',
    minStockLevel: 5,
    description: 'Description',
    isVatApplicable: true,
    isActive: true,
    openingStock: 25,
    imageId: 'image-$id',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
