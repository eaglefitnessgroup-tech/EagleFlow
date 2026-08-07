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

// Since we cannot mock SupabaseClient effectively without a full mock suite,
// we'll test the queue directly and the repositories' offline behavior.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late SyncCoordinator coordinator;

  setUp(() async {
    final factory = databaseFactoryMemory;
    db = await factory.openDatabase(
      'test_sync_coordinator_\${DateTime.now().millisecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(db);

    // Mock locator components
    ServiceLocator().authController.setCurrentUserForTesting(
      AppUser(
        id: 'ADMIN-001',
        name: 'Admin',
        username: 'admin',
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
  });
}
