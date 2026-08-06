class Reservation {
  final String id;
  final String productId;
  final String productName;
  final String productCode;
  final int quantity;
  final String reference;
  final DateTime reservedDate;
  final DateTime expiryDate;
  final String reservedBy;
  final String status;

  const Reservation({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.reference,
    required this.reservedDate,
    required this.expiryDate,
    required this.reservedBy,
    this.status = 'Active',
  });

  Reservation copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productCode,
    int? quantity,
    String? reference,
    DateTime? reservedDate,
    DateTime? expiryDate,
    String? reservedBy,
    String? status,
  }) {
    return Reservation(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      quantity: quantity ?? this.quantity,
      reference: reference ?? this.reference,
      reservedDate: reservedDate ?? this.reservedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      reservedBy: reservedBy ?? this.reservedBy,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'quantity': quantity,
      'reference': reference,
      'reservedDate': reservedDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'reservedBy': reservedBy,
      'status': status,
    };
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      productCode: json['productCode'] as String,
      quantity: json['quantity'] as int,
      reference: json['reference'] as String,
      reservedDate: DateTime.parse(json['reservedDate'] as String),
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      reservedBy: json['reservedBy'] as String,
      status: json['status'] as String? ?? 'Active',
    );
  }
}
