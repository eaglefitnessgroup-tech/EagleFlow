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

  final StoreRef<String, Map<String, dynamic>> _queueStore =
      stringMapStoreFactory.store('pending_sync_queue');

  SyncCoordinator({required this.client});

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    if (client == null) return;

    await _ensureSupabaseAuth();
    _setupRealtime();
    await processRetryQueue();
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
            .update({'auth_uid': uid})
            .eq('id', localUser.id);
      } catch (e) {
        debugPrint('Failed to map user auth_uid: $e');
      }
    }
  }

  void _setupRealtime() {
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
        .subscribe();
  }

  void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
    _isStarted = false;
  }

  // ── Retry Queue ────────────────────────────────────────────────────────────

  Future<void> queueFailedWrite(
    String type,
    Map<String, dynamic> payload,
  ) async {
    if (type != 'products' && type != 'quotations') return;

    final db = await DatabaseService().database;
    final id = payload['id'] as String;
    final key = '${type}_$id';

    await _queueStore.record(key).put(db, {
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> processRetryQueue() async {
    if (client == null) return;

    final db = await DatabaseService().database;
    final records = await _queueStore.find(db);

    for (var record in records) {
      final type = record.value['type'] as String;
      final payload = record.value['payload'] as Map<String, dynamic>;

      try {
        if (type == 'products') {
          await client!.from('products').upsert(payload);
          await _queueStore.record(record.key).delete(db);
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
          }
        }
      } catch (e) {
        debugPrint('Retry failed for ${record.key}: $e');
      }
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
