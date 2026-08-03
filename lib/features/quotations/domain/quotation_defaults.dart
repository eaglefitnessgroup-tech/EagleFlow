import 'customer_info.dart';
import 'quotation.dart';
import 'quotation_constants.dart';

class QuotationDefaults {
  QuotationDefaults._();

  /// Creates a new empty draft.
  ///
  /// [salespersonId] and [salespersonName] should be provided from the
  /// currently logged-in user.  Both default to empty string so callers
  /// that do not yet have a user (e.g. test helpers) still compile.
  static Quotation createEmptyDraft({
    String salespersonId = '',
    String salespersonName = '',
  }) {
    final now = DateTime.now();
    return Quotation(
      id: '',
      quotationNumber: '',
      customerInfo: const CustomerInfo(name: ''),
      salespersonId: salespersonId,
      salespersonName: salespersonName,
      createdDate: now,
      modifiedDate: now,
      validUntil: now.add(
        const Duration(days: QuotationConstants.defaultValidityDays),
      ),
      expectedDelivery: now.add(
        const Duration(days: QuotationConstants.defaultDeliveryDays),
      ),
    );
  }
}
