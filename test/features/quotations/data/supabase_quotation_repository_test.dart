import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/core/sync/sync_coordinator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/quotations/data/sembast_quotation_repository.dart';
import 'package:eagleflow/features/quotations/data/supabase_quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_status.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';

class FakeSupabaseQuotationRepository extends SupabaseQuotationRepository {
  List<Map<String, dynamic>> serverQuotations = [];
  bool overrideIsConnected = true;

  FakeSupabaseQuotationRepository(super.localCache, super.supabase);

  @override
  bool get isConnectedToServer => overrideIsConnected;

  @override
  Future<List<dynamic>> fetchQuotationsFromServer() async {
    if (!overrideIsConnected) throw Exception('Offline');
    return serverQuotations;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late SembastQuotationRepository localCache;
  late FakeSupabaseQuotationRepository repo;
  late ServiceLocator locator;

  setUp(() async {
    final factory = databaseFactoryMemory;
    db = await factory.openDatabase(
      'test_quotation_sync_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(db);

    locator = ServiceLocator();
    locator.syncCoordinator = SyncCoordinator(client: null);

    locator.authController.setCurrentUserForTesting(
      AppUser(
        id: 'ADMIN-001',
        name: 'Admin',
        username: 'admin',
        passwordHash: '',
        role: UserRole.admin,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    localCache = SembastQuotationRepository();

    // Reset supabase mock config if needed (not needed for this test since we mock connection)
    repo = FakeSupabaseQuotationRepository(localCache, locator.supabaseService);
  });

  tearDown(() async {
    await db.close();
  });

  Quotation createTestQuotation({
    String salespersonId = 'ADMIN-001',
    QuotationStatus status = QuotationStatus.draft,
  }) {
    return Quotation(
      id: '',
      quotationNumber: '',
      salespersonId: salespersonId,
      customerInfo: const CustomerInfo(
        name: 'Test Customer',
        company: 'Test Co',
        phone: '1234567890',
        email: 'test@example.com',
        projectLocation: 'Dubai',
      ),
      charges: const QuotationCharges(
        deliveryCharges: 100,
        installationCharges: 50,
        otherCharges: 0,
        overallDiscount: 0,
        vatPercentage: 5,
      ),
      customerNotes: 'Deliver between 9 AM - 5 PM.',
      internalNotes: 'VIP client, prioritize delivery.',
      status: status,
      createdDate: DateTime.now(),
      modifiedDate: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 14)),
      expectedDelivery: DateTime.now().add(const Duration(days: 3)),
      lineItems: [], // Normally this would have QuotationLineItem objects
    );
  }

  group('SupabaseQuotationRepository Tests', () {
    test('1. Online pull + cache and Remote newer record wins', () async {
      repo.overrideIsConnected = true;

      // Seed local cache with an older record
      final now = DateTime.now();
      final oldRecord = createTestQuotation().copyWith(
        id: 'Q1',
        quotationNumber: 'QT-0001-26',
        modifiedDate: now.subtract(const Duration(hours: 1)),
      );
      await localCache.saveQuotation(oldRecord);

      // Seed server with newer record
      repo.serverQuotations = [
        {
          'id': 'Q1',
          'quotation_number': 'QT-0001-26',
          'salesperson_id': 'ADMIN-001',
          'customer_name': 'Remote Customer',
          'status': 'sent',
          'created_at': oldRecord.createdDate.toIso8601String(),
          'updated_at': now.add(const Duration(hours: 2)).toIso8601String(),
          'valid_until': oldRecord.validUntil.toIso8601String(),
          'expected_delivery': oldRecord.expectedDelivery.toIso8601String(),
          'quotation_items': [],
        },
      ];

      await repo.init(); // Triggers sync
      await Future.delayed(const Duration(milliseconds: 50));

      final q = await repo.getQuotationByNumber('QT-0001-26');
      expect(q, isNotNull);
      expect(q!.customerInfo.name, 'Remote Customer');
      expect(q.status, QuotationStatus.sent);
    });

    test('2. Offline read fallback', () async {
      repo.overrideIsConnected = false;

      final q = createTestQuotation().copyWith(
        id: 'Q2',
        quotationNumber: 'QT-0002-26',
      );
      await localCache.saveQuotation(q);

      final list = await repo.getAllQuotations();
      expect(list.length, 1);
      expect(list.first.quotationNumber, 'QT-0002-26');
    });

    test(
      '3. Server number generation blocked offline for final save',
      () async {
        repo.overrideIsConnected = false;

        final q = createTestQuotation(status: QuotationStatus.sent);
        expect(
          () => repo.saveQuotation(q),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('Cannot finalize or save a non-draft quotation offline'),
            ),
          ),
        );
      },
    );



    test('5. Salesperson own-only rules', () async {
      // Simulate Salesperson
      locator.authController.setCurrentUserForTesting(
        AppUser(
          id: 'SALES-001',
          name: 'Sales',
          username: 'sales',
          passwordHash: '',
          role: UserRole.sales,
          createdAt: DateTime.parse('2026-08-01T12:00:00Z'),
          updatedAt: DateTime.parse('2026-08-01T12:00:00Z'),
        ),
      );

      final qAdmin = createTestQuotation(
        salespersonId: 'ADMIN-001',
      ).copyWith(id: 'Q-ADMIN', quotationNumber: 'QT-A');
      final qSales = createTestQuotation(
        salespersonId: 'SALES-001',
      ).copyWith(id: 'Q-SALES', quotationNumber: 'QT-S');
      await localCache.saveQuotation(qAdmin);
      await localCache.saveQuotation(qSales);

      final list = await repo.getAllQuotations();
      expect(list.length, 1);
      expect(list.first.salespersonId, 'SALES-001');

      // Attempt to save someone else's quotation
      expect(
        () => repo.saveQuotation(qAdmin),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains(
              'Unauthorized: Cannot modify quotations belonging to others',
            ),
          ),
        ),
      );
    });

    test('6. Admin read-all', () async {
      final qAdmin = createTestQuotation(
        salespersonId: 'ADMIN-001',
      ).copyWith(id: 'Q-ADMIN', quotationNumber: 'QT-A');
      final qSales = createTestQuotation(
        salespersonId: 'SALES-001',
      ).copyWith(id: 'Q-SALES', quotationNumber: 'QT-S');
      await localCache.saveQuotation(qAdmin);
      await localCache.saveQuotation(qSales);

      final list = await repo.getAllQuotations();
      expect(list.length, 2);
    });
  });
}
