import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../../features/products/data/supabase_product_repository.dart';
import '../../features/stock/data/supabase_stock_repository.dart';
import '../../features/quotations/data/supabase_quotation_repository.dart';
import '../../features/reservations/data/supabase_reservation_repository.dart';
class SyncCoordinator {
  final SupabaseClient? client;

  RealtimeChannel? _subscription;
  bool _isStarted = false;

  SyncCoordinator({required this.client});

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    if (client == null) return;

    // Run network tasks asynchronously to avoid blocking app startup
    _ensureSupabaseAuth().then((_) {
      _setupRealtime();
    });
  }

  Future<void> _ensureSupabaseAuth() async {
    final localUser = ServiceLocator().authController.currentUser;
    if (localUser == null) return;

    final session = client!.auth.currentSession;
    if (session == null) {
      try {
        await client!.auth.signInAnonymously();
      } catch (e) {
        debugPrint('Failed to sign in anonymously: $e');
        return;
      }
    }

    final uid = client!.auth.currentUser?.id;
    if (uid != null) {
      try {
        // Map local business ID to Supabase Auth UUID directly.
        await client!
            .from('app_users')
            .update({'supabase_uid': uid})
            .eq('id', localUser.id)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Failed to map user supabase_uid: $e');
      }
    }
  }



  void _setupRealtime() {
    if (_subscription != null) {
      client?.removeChannel(_subscription!);
      _subscription = null;
    }

    _subscription = client!
        .channel('public:sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) async {
            final table = payload.table;
            if (table == 'products') {
              final repo = ServiceLocator().productRepository;
              if (repo is SupabaseProductRepository) await repo.handleRealtimeEvent(payload);
            } else if (table == 'stock_movements') {
              final repo = ServiceLocator().stockRepository;
              if (repo is SupabaseStockRepository) await repo.handleRealtimeEvent(payload);
            } else if (table == 'quotations' || table == 'quotation_items') {
              final repo = ServiceLocator().quotationRepository;
              if (repo is SupabaseQuotationRepository) await repo.handleRealtimeEvent(payload);
            } else if (table == 'reservations') {
              final repo = ServiceLocator().reservationRepository;
              if (repo is SupabaseReservationRepository) await repo.handleRealtimeEvent(payload);
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('SyncCoordinator Realtime Status: $status, error: $error');
        });
  }

  void dispose() {
    if (_subscription != null) {
      client?.removeChannel(_subscription!);
      _subscription = null;
    }
    _isStarted = false;
  }

}
