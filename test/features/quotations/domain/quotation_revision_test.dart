import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';

void main() {
  group('Quotation revisions', () {
    test('legacy JSON defaults to an original quotation', () {
      final json = QuotationDefaults.createEmptyDraft().toJson()
        ..remove('baseQuotationId')
        ..remove('revisionNo');

      final quotation = Quotation.fromJson(json);

      expect(quotation.baseQuotationId, isNull);
      expect(quotation.revisionNo, 0);
    });

    test('revision fields round-trip through JSON', () {
      final quotation = QuotationDefaults.createEmptyDraft().copyWith(
        id: 'revision-id',
        quotationNumber: 'QT-AN-0027-26',
        baseQuotationId: 'base-id',
        revisionNo: 3,
      );

      final restored = Quotation.fromJson(quotation.toJson());

      expect(restored.baseQuotationId, 'base-id');
      expect(restored.revisionNo, 3);
      expect(restored.quotationNumber, 'QT-AN-0027-26');
    });

    test('displayQuotationNumber adds only the derived revision suffix', () {
      final original = QuotationDefaults.createEmptyDraft().copyWith(
        quotationNumber: 'QT-AN-0027-26',
      );
      final revision = original.copyWith(
        baseQuotationId: 'base-id',
        revisionNo: 2,
      );

      expect(original.displayQuotationNumber, 'QT-AN-0027-26');
      expect(revision.displayQuotationNumber, 'QT-AN-0027-26 / R2');
      expect(revision.quotationNumber, 'QT-AN-0027-26');
    });
  });
}
