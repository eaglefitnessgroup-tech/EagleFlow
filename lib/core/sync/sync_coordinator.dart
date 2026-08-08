import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sembast/sembast.dart';
import '../database/database_service.dart';
import '../di/service_locator.dart';
import '../../features/products/data/supabase_product_repository.dart';
import '../../features/stock/data/supabase_stock_repository.dart';
import '../../features/quotations/data/supabase_quotation_repository.dart';

class SyncCoordinator {
  final SupabaseClient? client;

  RealtimeChannel? _subscription;
  bool _isStarted = false;
  bool _isProcessingQueue = false;
  Timer? _fallbackTimer;

  final StoreRef<String, Map<String, dynamic>> _queueStore =
      stringMapStoreFactory.store('pending_sync_queue');

  SyncCoordinator({required this.client});

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    if (client == null) return;

    // Run network tasks asynchronously to avoid blocking app startup
    _ensureSupabaseAuth().then((_) {
      _setupRealtime();
      _startFallbackTimer();
      processRetryQueue();
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

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) => _onFallbackTick());
  }

  Future<void> _onFallbackTick() async {
    if (client == null || _isProcessingQueue) return;

    try {
      final db = await DatabaseService().database;
      final count = await _queueStore.count(db);
      if (count == 0) return;

      // Perform lightweight health check
      await client!
          .from('app_users')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Network or auth error, skip processing
      return;
    }

    await processRetryQueue();
  }

  @visibleForTesting
  Future<void> triggerFallbackTickForTesting() => _onFallbackTick();

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
              if (repo is SupabaseProductRepository) await repo.init();
            } else if (table == 'stock_movements') {
              final repo = ServiceLocator().stockRepository;
              if (repo is SupabaseStockRepository) await repo.init();
            } else if (table == 'quotations' || table == 'quotation_items') {
              final repo = ServiceLocator().quotationRepository;
              if (repo is SupabaseQuotationRepository) await repo.init();
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('SyncCoordinator Realtime Status: $status, error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('SyncCoordinator: Realtime reconnected, triggering processRetryQueue()');
            processRetryQueue();
          }
        });
  }

  void dispose() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (_subscription != null) {
      client?.removeChannel(_subscription!);
      _subscription = null;
    }
    _isStarted = false;
  }

  // ── Retry Queue ────────────────────────────────────────────────────────────

  Future<void> queueFailedWrite(
    String type,
    Map<String, dynamic> payload,
  ) async {
    if (type != 'products' && type != 'quotations' && type != 'reservations') {
      return;
    }

    final db = await DatabaseService().database;
    final id = payload['id'] as String;
    final key = '${type}_$id';

    debugPrint('SyncCoordinator: queueFailedWrite triggered for type: $type, id: $id');

    await _queueStore.record(key).put(db, {
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> processRetryQueue() async {
    debugPrint('SyncCoordinator: processRetryQueue() called');
    if (client == null) {
      debugPrint('SyncCoordinator: client is null, aborting processRetryQueue');
      return;
    }
    if (_isProcessingQueue) {
      debugPrint('SyncCoordinator: _isProcessingQueue is true, aborting processRetryQueue');
      return;
    }

    _isProcessingQueue = true;
    try {
      final db = await DatabaseService().database;
      final records = await _queueStore.find(db);
      debugPrint('SyncCoordinator: processRetryQueue found ${records.length} items in queue');

    for (var record in records) {
      final type = record.value['type'] as String;
      final payload = record.value['payload'] as Map<String, dynamic>;

      debugPrint('SyncCoordinator: Processing record ${record.key} of type $type');
      try {
        if (type == 'products') {
          await client!.from('products').upsert(payload);
          await _queueStore.record(record.key).delete(db);
          debugPrint('SyncCoordinator: Successfully processed and deleted ${record.key}');
        } else if (type == 'quotations') {
          // Remove imageBytes if present, just in case
          if (payload['lineItems'] != null) {
            for (var item in payload['lineItems'] as List<dynamic>) {
              item.remove('imageBytes');
            }
          }
          final res = await client!.rpc(
            'save_quotation',
            params: {'p_payload': payload},
          );
          if (res != null &&
              res is Map<String, dynamic> &&
              res.containsKey('error')) {
            // Keep in queue if it's an error, maybe? Or delete?
            // "Idempotent operations only. Retry automatically when connection returns."
            // If it's a permanent error (like validation), it shouldn't be queued forever.
            debugPrint("Error from save_quotation RPC: ${res['error']}");
          } else {
            if (res != null) {
              final repo = ServiceLocator().quotationRepository;
              if (repo is SupabaseQuotationRepository) {
                final localRec = await repo.localCache.getQuotationByNumber(
                  payload['quotationNumber'],
                );
                if (localRec != null) {
                  await repo.localCache.deleteQuotation(localRec.id);
                }
              }
            }
            await _queueStore.record(record.key).delete(db);
            debugPrint('SyncCoordinator: Successfully processed and deleted ${record.key}');
          }
        } else if (type == 'reservations') {
          await client!.from('reservations').upsert(payload);
          await _queueStore.record(record.key).delete(db);
          debugPrint('SyncCoordinator: Successfully processed and deleted ${record.key}');
        }
      } catch (e) {
        debugPrint('SyncCoordinator: Exception during processing ${record.key}: $e');
        if (type == 'reservations' &&
            (e.toString().contains('duplicate key value') ||
                e.toString().contains('23505'))) {
          // Unique constraint violation
          await _queueStore.record(record.key).delete(db);
          // Cancel local reservation and notify
          final id = payload['id'] as String;
          await ServiceLocator().reservationRepository.cancelReservation(id);

          // Re-sync from server to refresh cache
          await ServiceLocator().reservationRepository.syncFromServer();

          // Show message
          // Ideally we use a stream or global key to show a snackbar.
          // For now, we will print it, or if there's a way to show global notification:
          debugPrint(
            "Another user reserved this product while you were offline.",
          );
        } else {
          debugPrint('Retry failed for ${record.key}: $e');
        }
      }
    }
    } finally {
      _isProcessingQueue = false;
    }
  }

  @visibleForTesting
  Future<List<Map<String, dynamic>>> getQueueForTesting() async {
    final db = await DatabaseService().database;
    final records = await _queueStore.find(db);
    return records.map((e) => e.value).toList();
  }

  @visibleForTesting
  Future<void> clearQueueForTesting() async {
    final db = await DatabaseService().database;
    await _queueStore.delete(db);
  }
}
