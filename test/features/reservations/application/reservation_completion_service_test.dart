import 'package:eagleflow/features/reservations/application/reservation_completion_service.dart';
import 'package:eagleflow/features/reservations/domain/reservation.dart';
import 'package:eagleflow/features/reservations/domain/reservation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completes matching reservations through the status API', () async {
    final repository = _FakeReservationRepository([
      _reservation(id: 'matching-1', productId: 'product-a'),
      _reservation(id: 'other-product', productId: 'product-b'),
      _reservation(id: 'matching-2', productId: 'product-a'),
    ]);
    final service = ReservationCompletionService(repository);

    await service.completeReservation('product-a');

    expect(repository.completedIds, ['matching-1', 'matching-2']);
    expect(repository.savedReservations, isEmpty);
  });
}

Reservation _reservation({required String id, required String productId}) {
  final now = DateTime(2026, 1, 1);
  return Reservation(
    id: id,
    productId: productId,
    productName: 'Product',
    productCode: 'CODE',
    quantity: 1,
    reference: 'QT-1',
    reservedDate: now,
    expiryDate: now.add(const Duration(days: 7)),
    reservedById: 'user-1',
    reservedBy: 'User',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeReservationRepository implements ReservationRepository {
  _FakeReservationRepository(this.activeReservations);

  final List<Reservation> activeReservations;
  final List<String> completedIds = [];
  final List<Reservation> savedReservations = [];

  @override
  Future<List<Reservation>> getActiveReservations() async => activeReservations;

  @override
  Future<void> completeReservation(String id) async {
    completedIds.add(id);
  }

  @override
  Future<void> saveReservation(Reservation reservation) async {
    savedReservations.add(reservation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
