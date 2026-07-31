import 'customer_info.dart';
import 'quotation.dart';
import 'quotation_constants.dart';

class QuotationDefaults {
  QuotationDefaults._();

  static Quotation createEmptyDraft() {
    final now = DateTime.now();
    return Quotation(
      id: 'temp_draft_id',
      quotationNumber: 'QTN-${now.year}-00001',
      customerInfo: const CustomerInfo(name: ''),
      salespersonId: 'SP-001',
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
