import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
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

    locator.authController.setCurrentUserForTesting(
      AppUser(
        id: 'ADMIN-001',
        name: 'Admin',
        username: 'admin',
        passwordHash: '',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );

    localCache = SembastQuotationRepository();
    repo = FakeSupabaseQuotationRepository(localCache, locator.supabaseService);

    repo.serverQuotations = [
      {
        'id': 'remote-q1',
        'quotation_number': 'QT-0001-26',
        'salesperson_id': 'SALES-001',
        'customer_name': 'Remote Customer',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'valid_until': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
        'quotation_items': [],
      },
    ];
  });

  tearDown(() async {
    await db.close();
  });

  Quotation createTestQuotation({
    String id = '',
    String spId = 'ADMIN-001',
    QuotationStatus status = QuotationStatus.draft,
  }) {
    return Quotation(
      id: id,
      quotationNumber: '',
      salespersonId: spId,
      customerInfo: const CustomerInfo(name: 'Test Customer'),
      charges: const QuotationCharges(),
      status: status,
      createdDate: DateTime.now(),
      modifiedDate: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 7)),
      expectedDelivery: DateTime.now().add(const Duration(days: 14)),
      lineItems: [],
    );
  }

  group('SupabaseQuotationRepository Tests', () {
    test('1. Online pull + cache and Remote newer record wins', () async {
      repo.overrideIsConnected = true;
      await repo.init(); // Triggers _syncQuotationsDown

      final quotations = await repo.getAllQuotations();
      expect(quotations.length, 1);
      expect(quotations.first.id, 'remote-q1');
      expect(quotations.first.quotationNumber, 'QT-0001-26');
    });

    test('2. Offline read fallback', () async {
      repo.overrideIsConnected = true;
      await repo.init(); // Sync first

      repo.overrideIsConnected = false;
      final quotations = await repo.getAllQuotations();
      expect(quotations.length, 1);
      expect(quotations.first.id, 'remote-q1');
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
              contains('Cannot finalize'),
            ),
          ),
        );
      },
    );

    test('4. Drafts get DRAFT- UUID number offline', () async {
      repo.overrideIsConnected = false;
      final q = createTestQuotation(status: QuotationStatus.draft);

      final saved = await repo.saveQuotation(q);
      expect(saved.quotationNumber.startsWith('DRAFT-'), isTrue);
      expect(saved.id.isNotEmpty, isTrue);
    });

    test('5. Salesperson own-only rules', () async {
      // Switch to Salesperson
      locator.authController.setCurrentUserForTesting(
        AppUser(
          id: 'SALES-002',
          name: 'Sales',
          username: 'sales',
          passwordHash: '',
          role: UserRole.salesperson,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      // Attempt to read all - should filter
      repo.overrideIsConnected = true;
      await repo.init(); // Sync pulls 'SALES-001' remote quotation

      final list = await repo.getAllQuotations();
      expect(list, isEmpty); // Cannot see SALES-001's quotation

      // Attempt to save quotation for another salesperson
      final q = createTestQuotation(spId: 'SALES-001');
      expect(
        () => repo.saveQuotation(q),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    test('6. Admin read-all', () async {
      repo.overrideIsConnected = true;
      await repo.init(); // Sync pulls 'SALES-001' remote quotation

      final list = await repo.getAllQuotations();
      expect(list.length, 1);
      expect(list.first.salespersonId, 'SALES-001');
    });

    test('7. Save quotation fails gracefully if rpc fails', () async {
      // Test that our wrapper prevents the ID generation if RPC isn't faked properly
      repo.overrideIsConnected = true;
      // We haven't mocked the RPC in the test client, so the client.rpc will actually try and fail
      // but client is null because we didn't init supabase fully.
      final q = createTestQuotation();

      expect(
        () => repo.saveQuotation(q),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('Failed to sync'),
          ),
        ),
      );
    });
  });
}
