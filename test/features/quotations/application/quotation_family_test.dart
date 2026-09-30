import 'package:eagleflow/features/quotations/application/quotation_family.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_defaults.dart';
import 'package:eagleflow/features/quotations/presentation/previous_quotations_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Quotation _quotation({
  required String id,
  required String number,
  String? baseId,
  int revisionNo = 0,
  String customer = 'Customer',
  DateTime? createdDate,
}) {
  return QuotationDefaults.createEmptyDraft(salespersonId: 'sales-1').copyWith(
    id: id,
    quotationNumber: number,
    baseQuotationId: baseId,
    revisionNo: revisionNo,
    customerInfo: QuotationDefaults.createEmptyDraft().customerInfo.copyWith(
      name: customer,
    ),
    createdDate: createdDate ?? DateTime(2026, 9, revisionNo + 1),
  );
}

void main() {
  test('groups versions and exposes original edit plus revision actions', () {
    final original = _quotation(id: 'base', number: 'QT-AN-0027-26');
    final r1 = _quotation(
      id: 'r1',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 1,
    );
    final r2 = _quotation(
      id: 'r2',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 2,
    );
    final r3 = _quotation(
      id: 'r3',
      number: original.quotationNumber,
      baseId: original.id,
      revisionNo: 3,
    );

    final family = groupQuotationFamilies([r2, original, r3, r1]).single;

    expect(family.original.id, 'base');
    expect(family.revisions.map((q) => q.id), ['r1', 'r2', 'r3']);
    expect(family.latest.id, 'r3');
    expect(family.canEdit(original), isTrue);
    expect(family.canEdit(r1), isFalse);
    expect(family.canEdit(r3), isFalse);
    expect(family.canDelete(original), isFalse);
    expect(family.canRevise(original), isTrue);
    expect(family.canRevise(r1), isTrue);
    expect(family.canRevise(r2), isTrue);
    expect(family.canRevise(r3), isTrue);
  });

  test('standalone original retains edit, revise, duplicate, and delete', () {
    final original = _quotation(id: 'base', number: 'QT-AN-0028-26');
    final family = groupQuotationFamilies([original]).single;

    expect(family.canEdit(original), isTrue);
    expect(family.canRevise(original), isTrue);
    expect(family.canDuplicate(original), isTrue);
    expect(family.canDelete(original), isTrue);
  });

  test('recent quotations count each family once using its latest member', () {
    final now = DateTime.utc(2026, 9, 30);
    final oldOriginal = _quotation(
      id: 'old-base',
      number: 'QT-OLD',
      createdDate: now.subtract(const Duration(days: 90)),
    );
    final recentRevision = _quotation(
      id: 'old-r1',
      number: oldOriginal.quotationNumber,
      baseId: oldOriginal.id,
      revisionNo: 1,
      createdDate: now.subtract(const Duration(days: 1)),
    );
    final recentOriginal = _quotation(
      id: 'recent-base',
      number: 'QT-RECENT',
      createdDate: now,
    );

    final families = groupQuotationFamilies([
      oldOriginal,
      recentRevision,
      recentOriginal,
    ]);

    expect(families, hasLength(2));
    expect(countRecentQuotationFamilies(families, now: now), 2);
  });
}
