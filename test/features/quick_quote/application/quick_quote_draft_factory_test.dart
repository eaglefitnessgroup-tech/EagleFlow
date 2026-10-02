import 'dart:typed_data';

import 'package:eagleflow/features/products/domain/product_condition.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_draft_factory.dart';
import 'package:eagleflow/features/quick_quote/domain/quick_quote_result.dart';
import 'package:eagleflow/features/quotations/application/quotation_calculator.dart';
import 'package:eagleflow/features/quotations/application/quotation_controller.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quick_quote_test_fixture.dart';

void main() {
  test(
    'converts a valid result to an ordinary unsaved quotation snapshot',
    () async {
      final products = buildCompleteProducts();
      final richProductIndex = products.indexWhere(
        (product) => product.id == 'cardio-cross_trainer',
      );
      products[richProductIndex] = products[richProductIndex].copyWith(
        description: 'Commercial cross trainer snapshot',
        condition: ProductCondition.refurbished,
        imageId: 'image-cross-trainer',
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        isVatApplicable: false,
      );

      final fixture = QuickQuoteFixture(products: products);
      await fixture.initialize();
      expect(await fixture.controller.generate('100000'), isTrue);
      final result = fixture.controller.result!;

      final draft = QuickQuoteDraftFactory.create(
        result: result,
        salespersonId: 'salesperson-current',
      );

      expect(draft.id, isEmpty);
      expect(draft.quotationNumber, isEmpty);
      expect(draft.baseQuotationId, isNull);
      expect(draft.revisionNo, 0);
      expect(draft.status, QuotationStatus.draft);
      expect(draft.syncStatus, SyncStatus.pending);
      expect(draft.salespersonId, 'salesperson-current');
      expect(draft.lineItems, hasLength(result.selections.length));
      expect(
        draft.lineItems.map((item) => item.productId),
        result.selections.map((selection) => selection.productId),
      );
      expect(
        draft.lineItems.map((item) => item.quantity),
        result.selections.map((selection) => selection.quantity),
      );
      expect(
        result.selections.any((selection) => selection.quantity > 1),
        isTrue,
      );

      for (var index = 0; index < result.selections.length; index++) {
        final product = result.selections[index].candidate.product;
        final item = draft.lineItems[index];
        expect(item.productId, product.id);
        expect(item.productCode, product.productCode);
        expect(item.name, product.name);
        expect(item.brand, product.brand);
        expect(item.condition, product.condition);
        expect(item.unitPrice, product.sellingPrice);
        expect(item.quantity, result.selections[index].quantity);
        expect(item.discount, 0);
        expect(item.isVatApplicable, product.isVatApplicable);
        expect(item.imageId, product.imageId);
        expect(item.imageBytes, product.imageBytes);
        expect(item.description, product.description);
        expect(item.isCustom, isFalse);
      }

      final richItem = draft.lineItems.singleWhere(
        (item) => item.productId == 'cardio-cross_trainer',
      );
      expect(richItem.condition, ProductCondition.refurbished);
      expect(richItem.description, 'Commercial cross trainer snapshot');
      expect(richItem.imageId, 'image-cross-trainer');
      expect(richItem.imageBytes, Uint8List.fromList([1, 2, 3, 4]));
      expect(richItem.isVatApplicable, isFalse);

      expect(draft.charges.deliveryCharges, 0);
      expect(draft.charges.installationCharges, 0);
      expect(draft.charges.otherCharges, 0);
      expect(draft.charges.overallDiscount, 0);
      expect(draft.charges.vatPercentage, 5);
      expect(
        QuotationCalculator.calculateSubtotal(draft.lineItems),
        closeTo(result.subtotal, 0.000001),
      );
      expect(
        QuotationCalculator.calculateGrandTotal(draft.lineItems, draft.charges),
        closeTo(result.grandTotal, 0.000001),
      );

      final controller = QuotationController(draft);
      expect(controller.isRevisionDraft, isFalse);
      controller.dispose();
    },
  );

  test(
    'unsupported configured budget creates no draft and leaves revision flow intact',
    () async {
      final fixture = QuickQuoteFixture();
      await fixture.initialize();
      expect(await fixture.controller.generate('1'), isFalse);
      expect(fixture.controller.result, isNull);

      final source = QuickQuoteDraftFactory.create(
        result: await _validResult(),
        salespersonId: 'salesperson-current',
      ).copyWith(id: 'saved-source', quotationNumber: 'QT-001');
      final revision = QuotationController.forRevision(source);
      expect(revision.isRevisionDraft, isTrue);
      expect(revision.quotation.baseQuotationId, 'saved-source');
      expect(revision.quotation.revisionNo, 1);
      revision.dispose();
    },
  );
}

Future<QuickQuoteResult> _validResult() async {
  final fixture = QuickQuoteFixture();
  await fixture.initialize();
  await fixture.controller.generate('100000');
  return fixture.controller.result!;
}
