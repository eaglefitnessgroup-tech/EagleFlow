import 'reservation.dart';

abstract class ReservationRepository {
  Future<void> saveReservation(Reservation reservation);
  Future<List<Reservation>> getActiveReservations();
  Future<void> cancelReservation(String id);
}
