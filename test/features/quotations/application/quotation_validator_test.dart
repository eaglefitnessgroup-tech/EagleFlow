import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/application/quotation_validator.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';

void main() {
  group('QuotationValidator', () {
    test('canPreview is false if line items is empty', () {
      final draft = QuotationDefaults.createEmptyDraft();
      final draftWithCustomer = draft.copyWith(
        customerInfo: draft.customerInfo.copyWith(name: 'Valid Name'),
      );
      // Empty line items
      expect(QuotationValidator.canPreview(draftWithCustomer), isFalse);
    });

    test('canPreview is false if customer name is empty or whitespace', () {
      final draft = QuotationDefaults.createEmptyDraft();
      final item = const QuotationLineItem(
        id: '1',
        productId: 'p1',
        productCode: 'c1',
        name: 'Item',
        brand: 'Brand',
        unitPrice: 100.0,
        quantity: 1,
      );
      final draftWithItems = draft.copyWith(lineItems: [item]);

      // Blank name
      final blankNameDraft = draftWithItems.copyWith(
        customerInfo: draft.customerInfo.copyWith(name: ''),
      );
      expect(QuotationValidator.canPreview(blankNameDraft), isFalse);

      // Whitespace only
      final whitespaceNameDraft = draftWithItems.copyWith(
        customerInfo: draft.customerInfo.copyWith(name: '   '),
      );
      expect(QuotationValidator.canPreview(whitespaceNameDraft), isFalse);
    });

    test('canPreview is true if has line items and valid customer name', () {
      final draft = QuotationDefaults.createEmptyDraft();
      final item = const QuotationLineItem(
        id: '1',
        productId: 'p1',
        productCode: 'c1',
        name: 'Item',
        brand: 'Brand',
        unitPrice: 100.0,
        quantity: 1,
      );
      final draftWithItemsAndName = draft.copyWith(
        lineItems: [item],
        customerInfo: draft.customerInfo.copyWith(name: 'Acme Corp'),
      );

      expect(QuotationValidator.canPreview(draftWithItemsAndName), isTrue);
    });
  });
}
