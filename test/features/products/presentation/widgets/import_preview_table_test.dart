import 'package:eagleflow/features/products/domain/bulk_import_models.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/products/presentation/widgets/import_preview_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview displays the Product Condition label', (tester) async {
    final product = Product(
      id: 'product-1',
      productCode: 'SKU-001',
      name: 'Preview product',
      category: 'Equipment',
      brand: 'Eagle',
      condition: ProductCondition.refurbished,
      sellingPrice: 25,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );
    final preview = BulkImportPreview(
      rows: [BulkImportRow(rowIndex: 2, product: product)],
      totalRows: 1,
      validCount: 1,
      errorCount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ImportPreviewTable(preview: preview),
          ),
        ),
      ),
    );

    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('Refurbished'), findsOneWidget);
    expect(find.textContaining('ProductCondition.'), findsNothing);
  });
}
