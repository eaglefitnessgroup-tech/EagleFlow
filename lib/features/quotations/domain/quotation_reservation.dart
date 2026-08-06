import 'package:flutter/foundation.dart';

@immutable
class QuotationReservation {
  final String id;
  final String quotationId;
  final String quotationNumber;
  final String productId;
  final int reservedQty;
  final String salesmanId;
  final String salesmanName;
  final DateTime updatedAt;

  const QuotationReservation({
    required this.id,
    required this.quotationId,
    required this.quotationNumber,
    required this.productId,
    required this.reservedQty,
    required this.salesmanId,
    required this.salesmanName,
    required this.updatedAt,
  });

  QuotationReservation copyWith({
    String? id,
    String? quotationId,
    String? quotationNumber,
    String? productId,
    int? reservedQty,
    String? salesmanId,
    String? salesmanName,
    DateTime? updatedAt,
  }) {
    return QuotationReservation(
      id: id ?? this.id,
      quotationId: quotationId ?? this.quotationId,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      productId: productId ?? this.productId,
      reservedQty: reservedQty ?? this.reservedQty,
      salesmanId: salesmanId ?? this.salesmanId,
      salesmanName: salesmanName ?? this.salesmanName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotationId': quotationId,
      'quotationNumber': quotationNumber,
      'productId': productId,
      'reservedQty': reservedQty,
      'salesmanId': salesmanId,
      'salesmanName': salesmanName,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory QuotationReservation.fromJson(Map<String, dynamic> json) {
    return QuotationReservation(
      id: json['id'] as String,
      quotationId: json['quotationId'] as String,
      quotationNumber: json['quotationNumber'] as String,
      productId: json['productId'] as String,
      reservedQty: json['reservedQty'] as int,
      salesmanId: json['salesmanId'] as String,
      salesmanName: json['salesmanName'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

@immutable
class ReservationAggregation {
  final int reservedQty;
  final List<QuotationReservation> reservations;

  const ReservationAggregation({
    required this.reservedQty,
    required this.reservations,
  });

  factory ReservationAggregation.fromReservations(List<QuotationReservation> reservations) {
    final qty = reservations.fold(0, (sum, r) => sum + r.reservedQty);
    return ReservationAggregation(
      reservedQty: qty,
      reservations: reservations,
    );
  }
}
