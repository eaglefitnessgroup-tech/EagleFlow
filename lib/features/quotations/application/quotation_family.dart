import '../domain/quotation.dart';

class QuotationFamily {
  QuotationFamily({required this.original, required List<Quotation> members})
    : members = List.unmodifiable(_sortedMembers(members));

  final Quotation original;
  final List<Quotation> members;

  String get id => original.id.isNotEmpty
      ? original.id
      : 'quotation:${original.quotationNumber}';

  List<Quotation> get revisions =>
      members.where((quotation) => quotation.revisionNo > 0).toList();

  bool get hasRevisions => revisions.isNotEmpty;

  Quotation get latest => members.last;

  bool canEdit(Quotation quotation) => quotation.id == original.id;

  bool canRevise(Quotation quotation) =>
      members.any((member) => member.id == quotation.id);

  bool canDelete(Quotation quotation) =>
      !hasRevisions && quotation.id == original.id;

  bool canDuplicate(Quotation quotation) =>
      !hasRevisions && quotation.id == original.id;

  static List<Quotation> _sortedMembers(List<Quotation> source) {
    final sorted = List<Quotation>.from(source);
    sorted.sort((a, b) {
      final revisionComparison = a.revisionNo.compareTo(b.revisionNo);
      if (revisionComparison != 0) return revisionComparison;
      final dateComparison = a.createdDate.compareTo(b.createdDate);
      if (dateComparison != 0) return dateComparison;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }
}

List<QuotationFamily> groupQuotationFamilies(List<Quotation> quotations) {
  final originalsById = <String, Quotation>{};
  final membersByBaseId = <String, List<Quotation>>{};

  for (final quotation in quotations) {
    if (quotation.revisionNo == 0 && quotation.baseQuotationId == null) {
      final familyId = quotation.id.isNotEmpty
          ? quotation.id
          : 'quotation:${quotation.quotationNumber}';
      originalsById[familyId] = quotation;
      membersByBaseId.putIfAbsent(familyId, () => []).add(quotation);
    } else {
      final baseId = quotation.baseQuotationId ?? quotation.id;
      membersByBaseId.putIfAbsent(baseId, () => []).add(quotation);
    }
  }

  final families = <QuotationFamily>[];
  for (final entry in membersByBaseId.entries) {
    final members = entry.value;
    final original =
        originalsById[entry.key] ??
        members.reduce((a, b) => a.revisionNo <= b.revisionNo ? a : b);
    families.add(QuotationFamily(original: original, members: members));
  }
  return families;
}
