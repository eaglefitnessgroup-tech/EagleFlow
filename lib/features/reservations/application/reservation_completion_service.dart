import '../../../core/di/service_locator.dart';
import '../domain/reservation_repository.dart';

class ReservationCompletionService {
  ReservationCompletionService([this._repository]);

  final ReservationRepository? _repository;

  Future<void> completeReservation(String productId) async {
    final repository = _repository ?? ServiceLocator().reservationRepository;
    final activeReservations = await repository.getActiveReservations();
    final matchingReservations = activeReservations.where(
      (reservation) => reservation.productId == productId,
    );

    for (final res in matchingReservations) {
      await repository.completeReservation(res.id);
    }
  }
}
