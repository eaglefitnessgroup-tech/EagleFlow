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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotationNumber': quotationNumber,
      'customerInfo': customerInfo.toJson(),
      'salespersonId': salespersonId,
      'createdDate': createdDate.toIso8601String(),
      'modifiedDate': modifiedDate.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'expectedDelivery': expectedDelivery.toIso8601String(),
      'status': status.name,
      'syncStatus': syncStatus.name,
      'lineItems': lineItems.map((e) => e.toJson()).toList(),
      'charges': charges.toJson(),
      'customerNotes': customerNotes,
      'internalNotes': internalNotes,
    };
  }

  factory Quotation.fromJson(Map<String, dynamic> json) {
    return Quotation(
      id: json['id'] as String,
      quotationNumber: json['quotationNumber'] as String,
      customerInfo: CustomerInfo.fromJson(
        json['customerInfo'] as Map<String, dynamic>,
      ),
      salespersonId: json['salespersonId'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: DateTime.parse(json['modifiedDate'] as String),
      validUntil: DateTime.parse(json['validUntil'] as String),
      expectedDelivery: DateTime.parse(json['expectedDelivery'] as String),
      status: QuotationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => QuotationStatus.draft,
      ),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.pending,
      ),
      lineItems:
          (json['lineItems'] as List<dynamic>?)
              ?.map(
                (e) => QuotationLineItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      charges: QuotationCharges.fromJson(
        json['charges'] as Map<String, dynamic>,
      ),
      customerNotes: json['customerNotes'] as String? ?? '',
      internalNotes: json['internalNotes'] as String? ?? '',
    );
  }
}
