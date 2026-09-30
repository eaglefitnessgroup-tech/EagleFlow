import 'customer_info.dart';
import 'quotation_charges.dart';
import 'quotation_line_item.dart';
import 'quotation_status.dart';

class Quotation {
  final String id;
  final String quotationNumber;
  final String? baseQuotationId;
  final int revisionNo;
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
  final bool isStockOutProcessed;

  const Quotation({
    required this.id,
    required this.quotationNumber,
    this.baseQuotationId,
    this.revisionNo = 0,
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
    this.isStockOutProcessed = false,
  });

  String get displayQuotationNumber =>
      revisionNo > 0 ? '$quotationNumber / R$revisionNo' : quotationNumber;

  Quotation copyWith({
    String? id,
    String? quotationNumber,
    String? baseQuotationId,
    bool clearBaseQuotationId = false,
    int? revisionNo,
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
    bool? isStockOutProcessed,
  }) {
    return Quotation(
      id: id ?? this.id,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      baseQuotationId: clearBaseQuotationId
          ? null
          : baseQuotationId ?? this.baseQuotationId,
      revisionNo: revisionNo ?? this.revisionNo,
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
      isStockOutProcessed: isStockOutProcessed ?? this.isStockOutProcessed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotationNumber': quotationNumber,
      'baseQuotationId': baseQuotationId,
      'revisionNo': revisionNo,
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
      'isStockOutProcessed': isStockOutProcessed,
    };
  }

  factory Quotation.fromJson(Map<String, dynamic> json) {
    return Quotation(
      id: json['id'] as String,
      quotationNumber: json['quotationNumber'] as String,
      baseQuotationId: json['baseQuotationId'] as String?,
      revisionNo: (json['revisionNo'] as num?)?.toInt() ?? 0,
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
      isStockOutProcessed: json['isStockOutProcessed'] as bool? ?? false,
    );
  }
}
