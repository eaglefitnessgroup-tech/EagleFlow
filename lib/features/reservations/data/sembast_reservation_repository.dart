import 'package:sembast/sembast.dart';
import '../../../core/database/database_service.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

class SembastReservationRepository implements ReservationRepository {
  final StoreRef<String, Map<String, dynamic>> _store = 
      StoreRef<String, Map<String, dynamic>>('reservations');

  Future<Database> get _db async => await DatabaseService().database;

  @override
  Future<void> saveReservation(Reservation reservation) async {
    final db = await _db;
    await _store.record(reservation.id).put(db, reservation.toJson());
  }

  @override
  Future<List<Reservation>> getActiveReservations() async {
    final db = await _db;
    final records = await _store.find(
      db,
      finder: Finder(filter: Filter.equals('status', 'Active')),
    );
    return records.map((record) => Reservation.fromJson(record.value)).toList();
  }

  @override
  Future<void> cancelReservation(String id) async {
    final db = await _db;
    final record = await _store.record(id).get(db);
    if (record != null) {
      final reservation = Reservation.fromJson(record).copyWith(status: 'Cancelled');
      await _store.record(id).put(db, reservation.toJson());
    }
  }
}
