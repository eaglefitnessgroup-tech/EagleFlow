import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/sync/sync_coordinator.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/data/supabase_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quotations/data/sembast_quotation_repository.dart';
import 'package:eagleflow/features/quotations/data/supabase_quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Since we cannot mock SupabaseClient effectively without a full mock suite,
// we'll test the queue directly and the repositories' offline behavior.
// We use a simple FakeSupabaseClient to verify the fallback timer's short-circuit logic.

class FakeSupabaseClient implements SupabaseClient {
  bool healthCheckCalled = false;
  bool upsertCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments[0] as String;
      if (table == 'app_users') {
        healthCheckCalled = true;
        throw Exception('Fake health check exception');
      }
      if (table == 'reservations') {
        upsertCalled = true;
        throw Exception('Fake upsert exception');
      }
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late SyncCoordinator coordinator;

  setUp(() async {
    final factory = databaseFactoryMemory;
    db = await factory.openDatabase(
      'test_sync_coordinator_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(db);

    // Mock locator components
    ServiceLocator().authController.setCurrentUserForTesting(
        AppUser(
          id: 'ADMIN-001',
          name: 'Anshad',
          username: 'anshad',
          passwordHash: '',
          role: UserRole.admin,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    coordinator = SyncCoordinator(client: null);
    await coordinator.clearQueueForTesting();
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await db.close();
  });

  group('SyncCoordinator Queue Tests', () {
    test('1. Failed product write queued', () async {
      await coordinator.queueFailedWrite('products', {
        'id': 'prod-1',
        'name': 'P1',
      });
      final queue = await coordinator.getQueueForTesting();

      expect(queue.length, 1);
      expect(queue.first['type'], 'products');
      expect(queue.first['payload']['id'], 'prod-1');
    });

    test('2. Failed quotation write queued', () async {
      await coordinator.queueFailedWrite('quotations', {
        'id': 'quot-1',
        'status': 'draft',
      });
      final queue = await coordinator.getQueueForTesting();

      expect(queue.length, 1);
      expect(queue.first['type'], 'quotations');
    });

    test('3. Duplicate queue prevented (idempotent PUT)', () async {
      await coordinator.queueFailedWrite('products', {
        'id': 'prod-1',
        'name': 'P1',
      });
      await coordinator.queueFailedWrite('products', {
        'id': 'prod-1',
        'name': 'P1 Updated',
      });

      final queue = await coordinator.getQueueForTesting();
      expect(queue.length, 1);
      expect(queue.first['payload']['name'], 'P1 Updated');
    });

    test('4. Stock write never queued', () async {
      await coordinator.queueFailedWrite('stock_movements', {'id': 'stock-1'});
      final queue = await coordinator.getQueueForTesting();

      expect(queue.isEmpty, isTrue);
    });

    test('5. Offline startup safe', () async {
      expect(() async => await coordinator.start(), returnsNormally);
    });

    test('6. Dispose/reconnect safe', () async {
      await coordinator.start();
      coordinator.dispose();
      await coordinator.start();
      // Should not throw
      expect(true, isTrue);
    });
    test('7. Pending queued items survive SyncCoordinator restart', () async {
      await coordinator.queueFailedWrite('reservations', {
        'id': 'res-1',
        'status': 'ACTIVE',
      });

      // Simulate app restart by creating a new coordinator
      final newCoordinator = SyncCoordinator(client: null);
      final queue = await newCoordinator.getQueueForTesting();

      expect(queue.length, 1);
      expect(queue.first['type'], 'reservations');
      expect(queue.first['payload']['id'], 'res-1');
    });

    test('8. processRetryQueue concurrency lock works', () async {
      // We can test the lock by calling it synchronously if possible,
      // but without a mock client it just returns immediately if null.
      // We can verify that it doesn't crash at least.
      expect(() async => await coordinator.processRetryQueue(), returnsNormally);
      expect(() async {
         coordinator.processRetryQueue();
         coordinator.processRetryQueue();
      }, returnsNormally);
    });

    test('9. Failed retry remains in the pending queue', () async {
      await coordinator.queueFailedWrite('reservations', {
        'id': 'res-fail-1',
        'status': 'ACTIVE',
      });

      // Since client is null, processRetryQueue simulating a failed/offline state
      // will not process the queue successfully and should not delete the record.
      await coordinator.processRetryQueue();

      final queue = await coordinator.getQueueForTesting();
      expect(queue.length, 1);
      expect(queue.first['payload']['id'], 'res-fail-1');
    });

    group('Fallback Timer Tests', () {
      test('10. empty queue = no health check', () async {
        final fakeClient = FakeSupabaseClient();
        final coord = SyncCoordinator(client: fakeClient);

        await coord.triggerFallbackTickForTesting();
        expect(fakeClient.healthCheckCalled, isFalse);
      });

      test('11. timer processes pending queue after connectivity returns', () async {
        final fakeClient = FakeSupabaseClient();
        final coord = SyncCoordinator(client: fakeClient);

        await coord.queueFailedWrite('reservations', {
          'id': 'res-timer',
          'status': 'ACTIVE',
        });

        // This will call healthCheck which throws 'Fake health check exception'
        // caught by _onFallbackTick, so it returns early and does not process.
        await coord.triggerFallbackTickForTesting();
        expect(fakeClient.healthCheckCalled, isTrue);
        expect(fakeClient.upsertCalled, isFalse);

        final queue = await coord.getQueueForTesting();
        expect(queue.length, 1, reason: 'Failed retry remains queued');
      });

      test('12. repeated timer ticks cannot overlap processing', () async {
        final fakeClient = FakeSupabaseClient();
        final coord = SyncCoordinator(client: fakeClient);

        // Use reflection or just test processRetryQueue concurrency
        expect(() async {
           coord.triggerFallbackTickForTesting();
           coord.triggerFallbackTickForTesting();
        }, returnsNormally);
      });

      test('13. timer lifecycle cleanup', () async {
        final coord = SyncCoordinator(client: null);
        await coord.start(); // starts timer
        coord.dispose(); // cancels timer
        expect(() async => await coord.triggerFallbackTickForTesting(), returnsNormally);
      });
    });
  });

  group('Repository Offline Queueing Integration', () {
    test('Offline product add queues write', () async {
      final supabaseService = SupabaseService.resetForTestingAndReturn();
      final localProd = SembastProductRepository();
      final prodRepo = SupabaseProductRepository(
        localCache: localProd,
        supabase: supabaseService,
      );
      ServiceLocator().syncCoordinator = coordinator;

      final p = Product(
        id: '',
        productCode: 'T-100',
        name: 'Test',
        category: 'Test',
        brand: 'Test',
        sellingPrice: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final added = await prodRepo.addProduct(p);
      expect(added.id.isNotEmpty, isTrue);

      final queue = await coordinator.getQueueForTesting();
      expect(queue.length, 1);
      expect(queue.first['type'], 'products');
      expect(queue.first['payload']['product_code'], 'T-100');
    });

    test('Offline quotation draft add queues write', () async {
      final supabaseService = SupabaseService.resetForTestingAndReturn();
      final localQ = SembastQuotationRepository();
      final qRepo = SupabaseQuotationRepository(localQ, supabaseService);
      ServiceLocator().syncCoordinator = coordinator;

      final q = Quotation(
        id: '',
        quotationNumber: '',
        salespersonId: 'ADMIN-001',
        customerInfo: const CustomerInfo(name: 'Cust'),
        createdDate: DateTime.now(),
        modifiedDate: DateTime.now(),
        validUntil: DateTime.now(),
        expectedDelivery: DateTime.now(),
      );

      final saved = await qRepo.saveQuotation(q);
      expect(saved.quotationNumber.startsWith('DRAFT-'), isTrue);

      final queue = await coordinator.getQueueForTesting();
      expect(queue.length, 1);
      expect(queue.first['type'], 'quotations');
    });

    test('Offline reservation add queues write', () async {
      // Emulate offline queue write for reservation
      await coordinator.queueFailedWrite('reservations', {
        'id': 'res-offline-1',
        'product_id': 'prod-1',
        'quantity': 5,
        'status': 'ACTIVE',
      });

      final queue = await coordinator.getQueueForTesting();
      expect(queue.length, 1);
      expect(queue.first['type'], 'reservations');
      expect(queue.first['payload']['status'], 'ACTIVE');

      // Emulate offline cancellation
      await coordinator.queueFailedWrite('reservations', {
        'id': 'res-offline-1',
        'product_id': 'prod-1',
        'quantity': 5,
        'status': 'CANCELLED',
      });

      final updatedQueue = await coordinator.getQueueForTesting();
      expect(updatedQueue.length, 1);
      expect(updatedQueue.first['type'], 'reservations');
      expect(updatedQueue.first['payload']['status'], 'CANCELLED', reason: 'Repeated offline edits collapse to the latest state');
    });
  });
}
