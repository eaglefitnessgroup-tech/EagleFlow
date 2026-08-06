import 'reservation.dart';

abstract class ReservationRepository {
  Future<void> syncFromServer();
  Future<void> saveReservation(Reservation reservation);
  Future<List<Reservation>> getActiveReservations();
  Future<void> cancelReservation(String id);
  Future<void> completeReservation(String id);
  Future<void> expireReservation(String id);
  void dispose();
}
