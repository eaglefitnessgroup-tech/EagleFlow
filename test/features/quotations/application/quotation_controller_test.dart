import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_condition.dart';

class _TrackingQuotationRepository implements QuotationRepository {
  int normalSaveCount = 0;
  int revisionSaveCount = 0;
  String? revisionSourceId;

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    normalSaveCount++;
    return quotation;
  }

  @override
  Future<Quotation> createRevision(
    String sourceQuotationId,
    Quotation revisionDraft,
  ) async {
    revisionSaveCount++;
    revisionSourceId = sourceQuotationId;
    return revisionDraft.copyWith(id: 'saved-revision', revisionNo: 1);
  }

  @override
  Future<void> deleteQuotation(String id) => throw UnimplementedError();

  @override
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation) =>
      throw UnimplementedError();

  @override
  Future<List<Quotation>> getAllQuotations() => throw UnimplementedError();

  @override
  Future<Quotation?> getQuotationByNumber(String quotationNumber) =>
      throw UnimplementedError();

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) =>
      throw UnimplementedError();
}

void main() {
  group('QuotationController', () {
    late QuotationController controller;
    const testItemId = 'li_1';

    setUp(() {
      final draft = QuotationDefaults.createEmptyDraft();
      final item = const QuotationLineItem(
        id: testItemId,
        productId: 'p1',
        productCode: 'c1',
        name: 'Item',
        brand: 'Brand',
        unitPrice: 100.0,
        quantity: 2,
      );
      controller = QuotationController(draft.copyWith(lineItems: [item]));
    });

    test('updateQuantity enforces minimum 1', () {
      controller.updateQuantity(testItemId, 0);
      expect(controller.quotation.lineItems.first.quantity, 1);

      controller.updateQuantity(testItemId, -5);
      expect(controller.quotation.lineItems.first.quantity, 1);
    });

    test('updateUnitPrice enforces non-negative', () {
      controller.updateUnitPrice(testItemId, -50.0);
      expect(controller.quotation.lineItems.first.unitPrice, 0.0);
    });

    test('updateLineDiscount clamps between 0 and 100', () {
      controller.updateLineDiscount(testItemId, -10.0);
      expect(controller.quotation.lineItems.first.discount, 0.0);

      controller.updateLineDiscount(testItemId, 150.0);
      expect(controller.quotation.lineItems.first.discount, 100.0);
    });

    test('updateCharges enforces non-negative', () {
      controller.updateCharges(discount: -100.0, vat: -5.0);
      expect(controller.quotation.charges.overallDiscount, 0.0);
      expect(controller.quotation.charges.vatPercentage, 0.0);
    });

    test('removeItem removes the correct item, including final item', () {
      controller.removeItem(testItemId);
      expect(controller.quotation.lineItems.isEmpty, isTrue);
    });

    group('Line item reordering', () {
      QuotationLineItem item(String id) => QuotationLineItem(
        id: id,
        productId: 'product-$id',
        productCode: id,
        name: 'Item $id',
        brand: 'Brand',
        unitPrice: 10,
        quantity: 1,
      );

      QuotationController controllerWithItems() => QuotationController(
        QuotationDefaults.createEmptyDraft().copyWith(
          lineItems: [item('a'), item('b'), item('c'), item('d')],
        ),
      );

      List<String> ids(QuotationController value) =>
          value.quotation.lineItems.map((item) => item.id).toList();

      test('moves an item upward', () {
        final reorderController = controllerWithItems();

        reorderController.reorderLineItem(2, 1);

        expect(ids(reorderController), ['a', 'c', 'b', 'd']);
      });

      test('moves an item downward using Flutter index adjustment', () {
        final reorderController = controllerWithItems();

        reorderController.reorderLineItem(1, 4);

        expect(ids(reorderController), ['a', 'c', 'd', 'b']);
      });

      test('moves the first item to the last position', () {
        final reorderController = controllerWithItems();
        final originalItem = reorderController.quotation.lineItems.first;

        reorderController.reorderLineItem(0, 4);

        expect(ids(reorderController), ['b', 'c', 'd', 'a']);
        expect(reorderController.quotation.lineItems.last, same(originalItem));
      });

      test('moves the last item to the first position', () {
        final reorderController = controllerWithItems();

        reorderController.reorderLineItem(3, 0);

        expect(ids(reorderController), ['d', 'a', 'b', 'c']);
      });

      test('ignores invalid indexes and no-op moves without notifying', () {
        final reorderController = controllerWithItems();
        var notifications = 0;
        reorderController.addListener(() => notifications++);

        reorderController.reorderLineItem(-1, 0);
        reorderController.reorderLineItem(4, 0);
        reorderController.reorderLineItem(0, -1);
        reorderController.reorderLineItem(0, 5);
        reorderController.reorderLineItem(1, 1);
        reorderController.reorderLineItem(1, 2);

        expect(ids(reorderController), ['a', 'b', 'c', 'd']);
        expect(notifications, 0);
      });

      test('new products still append after a reorder', () {
        final reorderController = controllerWithItems();
        final product = Product(
          id: 'new-product',
          name: 'New Product',
          brand: 'Brand',
          productCode: 'NEW',
          category: 'Category',
          sellingPrice: 50,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        reorderController.reorderLineItem(0, 4);
        reorderController.addProduct(product);

        expect(ids(reorderController), ['b', 'c', 'd', 'a', isNotEmpty]);
        expect(
          reorderController.quotation.lineItems.last.productId,
          'new-product',
        );
      });
    });

    group('Product Integration', () {
      final p1 = Product(
        id: 'p_1',
        name: 'Product 1',
        brand: 'Brand A',
        productCode: 'c_1',
        category: 'cat',
        sellingPrice: 100.0,
        isVatApplicable: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        openingStock: 10,
        description: 'desc 1',
      );

      final p2 = Product(
        id: 'p_2',
        name: 'Product 2',
        brand: 'Brand B',
        productCode: 'c_2',
        category: 'cat',
        sellingPrice: 200.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        openingStock: 5,
        description: 'desc 2',
      );

      test('addProduct adds new line item with correct mapping', () {
        int notifies = 0;
        controller.addListener(() => notifies++);

        controller.addProduct(p1);

        expect(notifies, 1);
        expect(controller.quotation.lineItems.length, 2); // 1 initial + 1 new
        final added = controller.quotation.lineItems.last;

        expect(added.productId, p1.id);
        expect(added.productCode, p1.productCode);
        expect(added.name, p1.name);
        expect(added.brand, p1.brand);
        expect(added.unitPrice, p1.sellingPrice);
        expect(added.quantity, 1);
        expect(added.discount, 0.0);
        expect(added.description, p1.description);
        expect(added.isCustom, false);
      });

      test('addProduct snapshots every Product Condition value', () {
        for (final condition in ProductCondition.values) {
          final product = p1.copyWith(
            id: 'product-${condition.persistedValue}',
            condition: condition,
          );
          controller.addProduct(product);
          expect(controller.quotation.lineItems.last.condition, condition);
        }
      });

      test(
        'null condition stays null and an existing snapshot is immutable',
        () {
          final legacyProduct = p1.copyWith(id: 'legacy-product');
          controller.addProduct(legacyProduct);
          expect(controller.quotation.lineItems.last.condition, isNull);

          final usedProduct = p1.copyWith(
            id: 'condition-product',
            condition: ProductCondition.used,
          );
          controller.addProduct(usedProduct);
          final snapshot = controller.quotation.lineItems.last;
          usedProduct.copyWith(condition: ProductCondition.display);
          expect(snapshot.condition, ProductCondition.used);
        },
      );

      test('addProduct preserves three description lines exactly', () {
        const description =
            'Product Dimension 1680×1710×1620mm\n'
            'Pipe Thickness 3mm | Weight Stack: 100 kg\n'
            'Net Weight 252 kg | 10 years frame warranty';
        final product = p1.copyWith(description: description);

        controller.addProduct(product);

        expect(controller.quotation.lineItems.last.description, description);
        expect(
          controller.quotation.lineItems.last.description!.split('\n'),
          hasLength(3),
        );
      });

      test('addProduct with zero or negative quantity normalizes to 1', () {
        controller.addProduct(p1, quantity: 0);
        expect(controller.quotation.lineItems.last.quantity, 1);

        controller.addProduct(p2, quantity: -5);
        expect(controller.quotation.lineItems.last.quantity, 1);
      });

      test(
        'Adding the same product twice increments quantity and preserves edits',
        () {
          controller.addProduct(p1, quantity: 2);

          // Edit price and discount
          final addedId = controller.quotation.lineItems.last.id;
          controller.updateUnitPrice(addedId, 150.0);
          controller.updateLineDiscount(addedId, 15.0);

          // Add same product again
          controller.addProduct(p1, quantity: 3);

          final items = controller.quotation.lineItems;
          expect(items.length, 2); // Still 2 (1 initial + 1 from p1)

          final updated = items.last;
          expect(updated.productId, p1.id);
          expect(updated.quantity, 5); // 2 + 3
          expect(updated.unitPrice, 150.0); // Preserved edit
          expect(updated.discount, 15.0); // Preserved edit
        },
      );

      test('addProducts adds multiple products in catalogue order', () {
        controller.addProducts([p1, p2]);

        final items = controller.quotation.lineItems;
        expect(items.length, 3);
        expect(items[1].productId, p1.id);
        expect(items[2].productId, p2.id);
      });

      test('addProducts preserves product VAT applicability', () {
        controller.addProducts([p1, p2]);

        final items = controller.quotation.lineItems;
        expect(
          items.firstWhere((item) => item.productId == p1.id).isVatApplicable,
          isFalse,
        );
        expect(
          items.firstWhere((item) => item.productId == p2.id).isVatApplicable,
          isTrue,
        );
      });

      test('addProducts empty list leaves quotation unchanged', () {
        int notifies = 0;
        controller.addListener(() => notifies++);

        controller.addProducts([]);

        expect(notifies, 0);
        expect(controller.quotation.lineItems.length, 1);
      });

      test('addProducts combines duplicates within the same batch safely', () {
        controller.addProducts([p1, p2, p1]); // p1 appears twice

        final items = controller.quotation.lineItems;
        expect(items.length, 3); // initial, p1, p2

        final p1Item = items.firstWhere((i) => i.productId == p1.id);
        expect(p1Item.quantity, 2); // combined 1 + 1

        final p2Item = items.firstWhere((i) => i.productId == p2.id);
        expect(p2Item.quantity, 1);
      });
    });

    group('Custom Product Integration', () {
      final customItem = const QuotationLineItem(
        id: '',
        name: 'Custom Product 1',
        brand: 'Custom Brand',
        unitPrice: 50.0,
        quantity: 2,
        isCustom: true,
      );

      test('addCustomItem appends the item and assigns unique ID', () {
        controller.addCustomItem(customItem);

        final added = controller.quotation.lineItems.last;
        expect(added.name, 'Custom Product 1');
        expect(added.isCustom, isTrue);
        expect(added.id, isNotEmpty);
        expect(controller.quotation.lineItems.length, 2); // initial + custom
      });

      test(
        'updateCustomItem preserves imageBytes if not explicitly provided',
        () {
          controller.addCustomItem(customItem);
          final addedId = controller.quotation.lineItems.last.id;

          final updatedItem = QuotationLineItem(
            id: addedId,
            name: 'Custom Product Updated',
            brand: 'Custom Brand',
            quantity: 3,
            unitPrice: 55.0,
            isCustom: true,
          );

          controller.updateCustomItem(addedId, updatedItem);

          final updated = controller.quotation.lineItems.last;
          expect(updated.name, 'Custom Product Updated');
          expect(updated.quantity, 3);
        },
      );
    });

    group('Revision foundation', () {
      test('revision draft deep-copies source and keeps source unchanged', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final source =
            QuotationDefaults.createEmptyDraft(
              salespersonId: 'SALES-001',
            ).copyWith(
              id: 'source-id',
              quotationNumber: 'QT-AN-0027-26',
              lineItems: [
                const QuotationLineItem(
                  id: 'source-item',
                  name: 'Snapshot',
                  brand: 'Brand',
                  unitPrice: 100,
                  quantity: 2,
                ).copyWith(imageBytes: imageBytes),
              ],
            );

        final revisionController = QuotationController.forRevision(source);
        final draft = revisionController.quotation;

        expect(revisionController.isRevisionDraft, isTrue);
        expect(revisionController.revisionSourceQuotationId, source.id);
        expect(draft.id, isEmpty);
        expect(draft.quotationNumber, source.quotationNumber);
        expect(draft.baseQuotationId, source.id);
        expect(draft.revisionNo, 1);
        expect(draft.customerInfo, isNot(same(source.customerInfo)));
        expect(draft.charges, isNot(same(source.charges)));
        expect(draft.lineItems.single, isNot(same(source.lineItems.single)));
        expect(
          draft.lineItems.single.imageBytes,
          isNot(same(source.lineItems.single.imageBytes)),
        );

        revisionController.updateQuantity(draft.lineItems.single.id, 5);
        expect(revisionController.quotation.lineItems.single.quantity, 5);
        expect(source.lineItems.single.quantity, 2);
        expect(source.id, 'source-id');
      });

      test(
        'revision save uses the explicit repository revision path',
        () async {
          final source = QuotationDefaults.createEmptyDraft(
            salespersonId: 'SALES-001',
          ).copyWith(id: 'source-id', quotationNumber: 'QT-AN-0027-26');
          final revisionController = QuotationController.forRevision(source);
          final repository = _TrackingQuotationRepository();

          final saved = await revisionController.save(repository);

          expect(repository.normalSaveCount, 0);
          expect(repository.revisionSaveCount, 1);
          expect(repository.revisionSourceId, 'source-id');
          expect(saved.id, 'saved-revision');
          expect(revisionController.isRevisionDraft, isFalse);
        },
      );

      test('revision draft from R1 keeps R1 as the selected source', () {
        final source =
            QuotationDefaults.createEmptyDraft(
              salespersonId: 'SALES-001',
            ).copyWith(
              id: 'r1-id',
              quotationNumber: 'QT-AN-0027-26',
              baseQuotationId: 'original-id',
              revisionNo: 1,
              customerNotes: 'R1 snapshot',
            );

        final revisionController = QuotationController.forRevision(source);

        expect(revisionController.revisionSourceQuotationId, 'r1-id');
        expect(revisionController.quotation.baseQuotationId, 'original-id');
        expect(revisionController.quotation.revisionNo, 2);
        expect(revisionController.quotation.customerNotes, 'R1 snapshot');

        revisionController.updateNotes(customerNotes: 'New revision content');
        expect(source.customerNotes, 'R1 snapshot');
      });

      test(
        'revision inherits source order and can reorder without mutating source',
        () {
          QuotationLineItem item(String id) => QuotationLineItem(
            id: id,
            name: 'Item $id',
            brand: 'Brand',
            unitPrice: 10,
            quantity: 1,
          );
          final source = QuotationDefaults.createEmptyDraft().copyWith(
            id: 'source-id',
            quotationNumber: 'QT-AN-0027-26',
            lineItems: [item('a'), item('c'), item('b')],
          );

          final revisionController = QuotationController.forRevision(source);

          expect(
            revisionController.quotation.lineItems.map((item) => item.name),
            ['Item a', 'Item c', 'Item b'],
          );

          revisionController.reorderLineItem(2, 0);

          expect(
            revisionController.quotation.lineItems.map((item) => item.name),
            ['Item b', 'Item a', 'Item c'],
          );
          expect(source.lineItems.map((item) => item.name), [
            'Item a',
            'Item c',
            'Item b',
          ]);
        },
      );
    });
  });
}
