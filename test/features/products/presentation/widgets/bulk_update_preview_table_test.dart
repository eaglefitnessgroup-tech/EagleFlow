import 'package:eagleflow/features/products/domain/bulk_update_models.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/products/presentation/widgets/bulk_update_preview_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Condition preview uses display labels only', (tester) async {
    const row = BulkProductUpdatePreviewRow(
      sourceRowNumber: 2,
      originalProductCode: 'SKU-001',
      normalizedProductCode: 'SKU-001',
      matchedProductId: 'product-1',
      patch: ProductUpdatePatch(condition: ProductCondition.refurbished),
      changes: [
        BulkProductUpdateChange(
          fieldKey: 'condition',
          displayLabel: 'Condition',
          oldValue: ProductCondition.used,
          newValue: ProductCondition.refurbished,
        ),
      ],
      status: BulkProductUpdateRowStatus.valid,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: BulkUpdatePreviewTable(rows: [row]),
          ),
        ),
      ),
    );

    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('Used → Refurbished'), findsOneWidget);
    expect(find.textContaining('ProductCondition.'), findsNothing);
  });
}
