class Reservation {
  final String id;
  final String productId;
  final String productName;
  final String productCode;
  final int quantity;
  final String reference;
  final DateTime reservedDate;
  final DateTime expiryDate;
  final String reservedById;
  final String reservedBy;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reservation({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.reference,
    required this.reservedDate,
    required this.expiryDate,
    required this.reservedById,
    required this.reservedBy,
    this.status = 'ACTIVE',
    required this.createdAt,
    required this.updatedAt,
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
    String? reservedById,
    String? reservedBy,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      reservedById: reservedById ?? this.reservedById,
      reservedBy: reservedBy ?? this.reservedBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'reservedById': reservedById,
      'reservedBy': reservedBy,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
      reservedById: json['reservedById'] as String? ?? '',
      reservedBy: json['reservedBy'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.parse(json['reservedDate'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.parse(json['reservedDate'] as String),
    );
  }
}
