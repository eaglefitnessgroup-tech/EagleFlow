enum StockMovementType { stockIn, stockOut }

class StockMovement {
  final String id;
  final String productId;
  final StockMovementType type;
  final int quantity;
  final String reference;
  final DateTime movementDate;
  final DateTime createdAt;
  final String createdBy;

  const StockMovement._({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.reference,
    required this.movementDate,
    required this.createdAt,
    required this.createdBy,
  });

  factory StockMovement({
    required String id,
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String reference,
    required DateTime movementDate,
    required DateTime createdAt,
    String createdBy = 'system',
  }) {
    if (quantity <= 0) {
      throw ArgumentError('quantity must be strictly greater than 0');
    }
    return StockMovement._(
      id: id,
      productId: productId,
      type: type,
      quantity: quantity,
      reference: reference,
      movementDate: movementDate,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      productId: json['productId'] as String,
      type: StockMovementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StockMovementType.stockIn,
      ),
      quantity: json['quantity'] as int,
      reference: json['reference'] as String,
      movementDate: DateTime.parse(json['movementDate'] as String).toUtc(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      createdBy: json['createdBy'] as String? ?? 'system',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'type': type.name,
      'quantity': quantity,
      'reference': reference,
      'movementDate': movementDate.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'createdBy': createdBy,
    };
  }

  StockMovement copyWith({
    String? id,
    String? productId,
    StockMovementType? type,
    int? quantity,
    String? reference,
    DateTime? movementDate,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      reference: reference ?? this.reference,
      movementDate: movementDate ?? this.movementDate,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
