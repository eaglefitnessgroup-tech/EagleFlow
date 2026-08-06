import '../../../core/di/service_locator.dart';

class ReservationCompletionService {
  Future<void> completeReservation(String productId) async {
    final activeReservations = await ServiceLocator()
        .reservationRepository
        .getActiveReservations();
    
    final matchingReservations = activeReservations.where((r) => r.productId == productId);
    
    for (final res in matchingReservations) {
      final completed = res.copyWith(status: 'Completed');
      await ServiceLocator().reservationRepository.saveReservation(completed);
    }
  }
}
