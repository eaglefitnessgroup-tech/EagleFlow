import 'customer_info.dart';
import 'quotation_charges.dart';
import 'quotation_line_item.dart';
import 'quotation_status.dart';

class Quotation {
  final String id;
  final String quotationNumber;
  final CustomerInfo customerInfo;
  final String salespersonId;
  final DateTime createdDate;
  final DateTime modifiedDate;
  final DateTime validUntil;
  final DateTime expectedDelivery;
  final QuotationStatus status;
  final SyncStatus syncStatus;
  final List<QuotationLineItem> lineItems;
  final QuotationCharges charges;
  final String customerNotes;
  final String internalNotes;

  const Quotation({
    required this.id,
    required this.quotationNumber,
    required this.customerInfo,
    required this.salespersonId,
    required this.createdDate,
    required this.modifiedDate,
    required this.validUntil,
    required this.expectedDelivery,
    this.status = QuotationStatus.draft,
    this.syncStatus = SyncStatus.pending,
    this.lineItems = const [],
    this.charges = const QuotationCharges(),
    this.customerNotes = '',
    this.internalNotes = '',
  });

  Quotation copyWith({
    String? id,
    String? quotationNumber,
    CustomerInfo? customerInfo,
    String? salespersonId,
    DateTime? createdDate,
    DateTime? modifiedDate,
    DateTime? validUntil,
    DateTime? expectedDelivery,
    QuotationStatus? status,
    SyncStatus? syncStatus,
    List<QuotationLineItem>? lineItems,
    QuotationCharges? charges,
    String? customerNotes,
    String? internalNotes,
  }) {
    return Quotation(
      id: id ?? this.id,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      customerInfo: customerInfo ?? this.customerInfo,
      salespersonId: salespersonId ?? this.salespersonId,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      validUntil: validUntil ?? this.validUntil,
      expectedDelivery: expectedDelivery ?? this.expectedDelivery,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      lineItems: lineItems ?? this.lineItems,
      charges: charges ?? this.charges,
      customerNotes: customerNotes ?? this.customerNotes,
      internalNotes: internalNotes ?? this.internalNotes,
    );
  }
}
