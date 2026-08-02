import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/stock/domain/stock_movement.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('StockMovement Domain Tests', () {
    test('JSON round-trip preserves all fields', () {
      final now = DateTime.now().toUtc();
      final id = const Uuid().v4();

      final movement = StockMovement(
        id: id,
        productId: 'prod-123',
        type: StockMovementType.stockIn,
        quantity: 50,
        reference: 'Initial Stock',
        movementDate: now,
        createdAt: now,
        createdBy: 'admin',
      );

      final json = movement.toJson();
      final fromJson = StockMovement.fromJson(json);

      expect(fromJson.id, movement.id);
      expect(fromJson.productId, movement.productId);
      expect(fromJson.type, movement.type);
      expect(fromJson.quantity, movement.quantity);
      expect(fromJson.reference, movement.reference);
      // toIso8601String trims microseconds differently depending on platform, so compare strings
      expect(
        fromJson.movementDate.toIso8601String(),
        movement.movementDate.toIso8601String(),
      );
      expect(
        fromJson.createdAt.toIso8601String(),
        movement.createdAt.toIso8601String(),
      );
      expect(fromJson.createdBy, movement.createdBy);
    });

    test('stockOut works and serialization preserves enum', () {
      final now = DateTime.now().toUtc();

      final movement = StockMovement(
        id: '1',
        productId: 'prod-123',
        type: StockMovementType.stockOut,
        quantity: 10,
        reference: 'Sales',
        movementDate: now,
        createdAt: now,
      );

      expect(movement.type, StockMovementType.stockOut);

      final json = movement.toJson();
      expect(json['type'], 'stockOut');

      final fromJson = StockMovement.fromJson(json);
      expect(fromJson.type, StockMovementType.stockOut);
    });

    test('Rejects zero quantity', () {
      expect(
        () => StockMovement(
          id: '1',
          productId: 'prod-1',
          type: StockMovementType.stockIn,
          quantity: 0,
          reference: 'Ref',
          movementDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rejects negative quantity', () {
      expect(
        () => StockMovement(
          id: '1',
          productId: 'prod-1',
          type: StockMovementType.stockOut,
          quantity: -5,
          reference: 'Ref',
          movementDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
