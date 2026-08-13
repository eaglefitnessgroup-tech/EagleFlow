import 'package:sembast/sembast.dart';
import '../../../core/database/database_service.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

class SembastReservationRepository implements ReservationRepository {
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store('reservations');

  Future<Database> get _db async => await DatabaseService().database;

  @override
  Future<void> syncFromServer() async {
    // No-op for purely local cache. Sync is handled by Supabase wrapper.
  }

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
      finder: Finder(filter: Filter.equals('status', 'ACTIVE')),
    );
    
    final now = DateTime.now();
    final List<Reservation> activeReservations = [];
    
    for (final record in records) {
      final reservation = Reservation.fromJson(Map<String, dynamic>.from(record.value));
      if (now.isAfter(reservation.expiryDate)) {
        final expired = reservation.copyWith(status: 'EXPIRED');
        await _store.record(reservation.id).put(db, expired.toJson());
      } else {
        activeReservations.add(reservation);
      }
    }
    
    return activeReservations;
  }

  @override
  Future<void> cancelReservation(String id) async {
    final db = await _db;
    final record = await _store.record(id).get(db);
    if (record != null) {
      final reservation = Reservation.fromJson(Map<String, dynamic>.from(record)).copyWith(status: 'CANCELLED');
      await _store.record(id).put(db, reservation.toJson());
    }
  }

  @override
  Future<void> completeReservation(String id) async {
    final db = await _db;
    final record = await _store.record(id).get(db);
    if (record != null) {
      final reservation = Reservation.fromJson(Map<String, dynamic>.from(record)).copyWith(status: 'COMPLETED');
      await _store.record(id).put(db, reservation.toJson());
    }
  }

  @override
  Future<void> expireReservation(String id) async {
    final db = await _db;
    final record = await _store.record(id).get(db);
    if (record != null) {
      final reservation = Reservation.fromJson(Map<String, dynamic>.from(record)).copyWith(status: 'EXPIRED');
      await _store.record(id).put(db, reservation.toJson());
    }
  }

  @override
  void dispose() {
    // No-op for local cache
  }
}
