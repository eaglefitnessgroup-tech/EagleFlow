import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sembast/sembast.dart';
import '../../../core/database/database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/di/service_locator.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';
import 'sembast_reservation_repository.dart';

class SupabaseReservationRepository implements ReservationRepository {
  final SembastReservationRepository localCache;
  final SupabaseService supabase;

  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store('reservations');

  Future<void>? _activeSync;
  RealtimeChannel? _subscription;

  bool get isConnectedToServer => supabase.isConnected;

  SupabaseReservationRepository({
    required this.localCache,
    required this.supabase,
  });

  Future<Database> get _db async => await DatabaseService().database;

  @override
  Future<void> syncFromServer() async {
    if (!isConnectedToServer) return;

    if (_activeSync != null) return _activeSync!;

    _activeSync = _performSyncDown().whenComplete(() {
      _activeSync = null;
    });

    return _activeSync!;
  }

  Future<void> _performSyncDown() async {
    try {
      final serverReservations =
          await supabase.client!.from('reservations').select();

      final db = await _db;
      await db.transaction((txn) async {
        for (var row in serverReservations) {
          final serverRes = _fromSupabase(row);

          final localRecord = await _store.record(serverRes.id).get(txn);

          if (localRecord == null) {
            await _store.record(serverRes.id).put(txn, serverRes.toJson());
          } else {
            final localRes = Reservation.fromJson(Map<String, dynamic>.from(localRecord));
            if (serverRes.updatedAt.isAfter(localRes.updatedAt)) {
              await _store.record(serverRes.id).put(txn, serverRes.toJson());
            }
          }
        }
      });
      
      _setupRealtime();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  void _setupRealtime() {
    if (_subscription != null) {
      supabase.client?.removeChannel(_subscription!);
      _subscription = null;
    }
    
    if (!isConnectedToServer) return;

    _subscription = supabase.client!
        .channel('public:reservations')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (payload) async {
              if (payload.newRecord.isNotEmpty) {
                final serverRes = _fromSupabase(payload.newRecord);
                final db = await _db;
                await _store.record(serverRes.id).put(db, serverRes.toJson());
              }
            })
        .subscribe();
  }

  @override
  Future<void> saveReservation(Reservation reservation) async {
    // Before save: If online, check Supabase.
    if (isConnectedToServer) {
      try {
        final existing = await supabase.client!
            .from('reservations')
            .select('id')
            .eq('product_id', reservation.productId)
            .eq('status', 'ACTIVE')
            .maybeSingle();

        if (existing != null) {
          throw Exception('Another user has already reserved this item.');
        }
      } catch (e) {
        if (e.toString().contains('Another user has already reserved')) {
          rethrow;
        }
        // If checking fails for network reasons, we fall through to offline handling.
      }
    }

    final updatedReservation = reservation.copyWith(
      updatedAt: DateTime.now(),
    );

    // Save to Supabase first or queue
    try {
      if (!isConnectedToServer) throw Exception('Offline');
      await supabase.client!
          .from('reservations')
          .upsert(_toSupabase(updatedReservation));
    } catch (e) {
      if (e.toString().contains('duplicate key value') || e.toString().contains('23505')) {
         throw Exception('Another user has already reserved this item.');
      }
      await ServiceLocator().syncCoordinator.queueFailedWrite(
        'reservations',
        _toSupabase(updatedReservation),
      );
    }

    // Save locally
    final db = await _db;
    await _store.record(updatedReservation.id).put(db, updatedReservation.toJson());
  }

  @override
  Future<List<Reservation>> getActiveReservations() async {
    return localCache.getActiveReservations();
  }

  @override
  Future<void> cancelReservation(String id) async {
    await _updateStatus(id, 'CANCELLED');
  }

  @override
  Future<void> completeReservation(String id) async {
    await _updateStatus(id, 'COMPLETED');
  }

  @override
  Future<void> expireReservation(String id) async {
    await _updateStatus(id, 'EXPIRED');
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final db = await _db;
    final record = await _store.record(id).get(db);
    if (record == null) return;
    
    final reservation = Reservation.fromJson(Map<String, dynamic>.from(record)).copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    try {
      if (!isConnectedToServer) throw Exception('Offline');
      await supabase.client!
          .from('reservations')
          .upsert(_toSupabase(reservation));
    } catch (e) {
      await ServiceLocator().syncCoordinator.queueFailedWrite(
        'reservations',
        _toSupabase(reservation),
      );
    }

    await _store.record(id).put(db, reservation.toJson());
  }

  Map<String, dynamic> _toSupabase(Reservation res) {
    return {
      'id': res.id,
      'product_id': res.productId,
      'product_name': res.productName,
      'product_code': res.productCode,
      'quantity': res.quantity,
      'reference': res.reference,
      'reserved_by_id': res.reservedById,
      'reserved_by_name': res.reservedBy,
      'reserved_date': res.reservedDate.toIso8601String(),
      'expiry_date': res.expiryDate.toIso8601String(),
      'status': res.status,
      'created_at': res.createdAt.toIso8601String(),
      'updated_at': res.updatedAt.toIso8601String(),
    };
  }

  Reservation _fromSupabase(Map<String, dynamic> row) {
    return Reservation(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      productName: row['product_name'] as String,
      productCode: row['product_code'] as String,
      quantity: row['quantity'] as int,
      reference: row['reference'] as String,
      reservedById: row['reserved_by_id'] as String,
      reservedBy: row['reserved_by_name'] as String,
      reservedDate: DateTime.parse(row['reserved_date'] as String),
      expiryDate: DateTime.parse(row['expiry_date'] as String),
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  @override
  void dispose() {
    if (_subscription != null) {
      supabase.client?.removeChannel(_subscription!);
      _subscription = null;
    }
  }
}
