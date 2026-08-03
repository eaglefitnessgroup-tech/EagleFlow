import 'customer_info.dart';
import 'quotation.dart';
import 'quotation_constants.dart';

class QuotationDefaults {
  QuotationDefaults._();

  /// Creates a new empty draft.
  ///
  /// [salespersonId] should be provided from the currently logged-in user.
  /// Defaults to empty string so callers without a user (e.g. test helpers)
  /// still compile.
  static Quotation createEmptyDraft({String salespersonId = ''}) {
    final now = DateTime.now();
    return Quotation(
      id: '',
      quotationNumber: '',
      customerInfo: const CustomerInfo(name: ''),
      salespersonId: salespersonId,
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
