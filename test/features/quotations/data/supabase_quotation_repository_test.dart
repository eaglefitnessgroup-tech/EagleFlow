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
import 'package:eagleflow/features/products/domain/product_condition.dart';

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

  @override
  Future<Map<String, dynamic>?> fetchQuotationByNumberFromServer(
    String quotationNumber,
  ) async {
    if (!overrideIsConnected) throw Exception('Offline');
    final matches =
        serverQuotations
            .where((row) => row['quotation_number'] == quotationNumber)
            .toList()
          ..sort((a, b) {
            final revisionCompare = ((b['revision_no'] as num?)?.toInt() ?? 0)
                .compareTo((a['revision_no'] as num?)?.toInt() ?? 0);
            if (revisionCompare != 0) return revisionCompare;
            return (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            );
          });
    return matches.isEmpty ? null : Map<String, dynamic>.from(matches.first);
  }
}

class TrackingSembastQuotationRepository extends SembastQuotationRepository {
  int imageReadCount = 0;

  @override
  Future<Quotation> getQuotationWithImages(Quotation quotation) async {
    imageReadCount++;
    return super.getQuotationWithImages(quotation);
  }
}

class DuplicateTestQuotationRepository extends FakeSupabaseQuotationRepository {
  int saveCount = 0;
  Quotation? saveInput;

  DuplicateTestQuotationRepository(super.localCache, super.supabase);

  @override
  Future<Quotation> saveQuotation(Quotation quotation) async {
    saveCount++;
    saveInput = quotation;
    return quotation.copyWith(
      id: 'DUPLICATED-QUOTATION',
      quotationNumber: 'DRAFT-DUPLICATE',
    );
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
          'base_quotation_id': 'Q0',
          'revision_no': 2,
          'salesperson_id': 'ADMIN-001',
          'customer_name': 'Remote Customer',
          'status': 'sent',
          'created_at': oldRecord.createdDate.toIso8601String(),
          'updated_at': now.add(const Duration(hours: 2)).toIso8601String(),
          'valid_until': oldRecord.validUntil.toIso8601String(),
          'expected_delivery': oldRecord.expectedDelivery.toIso8601String(),
          'quotation_items': [
            {
              'id': 'remote-item-1',
              'product_id': 'product-1',
              'product_code': 'CODE-1',
              'name': 'Third Product',
              'brand': 'Brand',
              'condition': 'refurbished',
              'unit_price': 100,
              'quantity': 1,
              'discount': 0,
              'sort_order': 2,
            },
            {
              'id': 'remote-item-2',
              'product_id': 'product-2',
              'product_code': 'CODE-2',
              'name': 'First Product',
              'brand': 'Brand',
              'unit_price': 200,
              'quantity': 1,
              'discount': 0,
              'sort_order': 0,
            },
            {
              'id': 'remote-item-3',
              'product_id': 'product-3',
              'product_code': 'CODE-3',
              'name': 'Second Product',
              'brand': 'Brand',
              'unit_price': 300,
              'quantity': 1,
              'discount': 0,
              'sort_order': 1,
            },
          ],
        },
      ];

      await repo.init(); // Triggers sync
      await Future.delayed(const Duration(milliseconds: 50));

      final q = await repo.getQuotationByNumber('QT-0001-26');
      expect(q, isNotNull);
      expect(q!.customerInfo.name, 'Remote Customer');
      expect(q.baseQuotationId, 'Q0');
      expect(q.revisionNo, 2);
      expect(q.status, QuotationStatus.sent);
      expect(q.lineItems.map((item) => item.name), [
        'First Product',
        'Second Product',
        'Third Product',
      ]);
      expect(q.lineItems.last.condition, ProductCondition.refurbished);
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
      expect(await repo.getQuotationByNumber('QT-A'), isNull);

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

    test(
      '6. Admin can look up a salesperson quotation without broadening lists or edits',
      () async {
        final qAdmin = createTestQuotation(
          salespersonId: 'ADMIN-001',
        ).copyWith(id: 'Q-ADMIN', quotationNumber: 'QT-A');
        final qSales = createTestQuotation(
          salespersonId: 'SALES-001',
        ).copyWith(id: 'Q-SALES', quotationNumber: 'QT-S');
        await localCache.saveQuotation(qAdmin);
        await localCache.saveQuotation(qSales);

        repo.serverQuotations = [
          {
            'id': qSales.id,
            'quotation_number': qSales.quotationNumber,
            'revision_no': 0,
            'salesperson_id': qSales.salespersonId,
            'customer_name': qSales.customerInfo.name,
            'customer_company': qSales.customerInfo.company,
            'customer_phone': qSales.customerInfo.phone,
            'customer_email': qSales.customerInfo.email,
            'project_location': qSales.customerInfo.projectLocation,
            'status': qSales.status.name,
            'created_at': qSales.createdDate.toUtc().toIso8601String(),
            'updated_at': qSales.modifiedDate.toUtc().toIso8601String(),
            'valid_until': qSales.validUntil.toUtc().toIso8601String(),
            'expected_delivery': qSales.expectedDelivery
                .toUtc()
                .toIso8601String(),
            'quotation_items': <Map<String, dynamic>>[],
          },
        ];

        final list = await repo.getAllQuotations();
        expect(list, hasLength(1));
        expect(list.single.salespersonId, 'ADMIN-001');
        final salespersonQuotation = await repo.getQuotationByNumber('QT-S');
        expect(salespersonQuotation, isNotNull);
        expect(salespersonQuotation!.salespersonId, 'SALES-001');
        expect(
          () => repo.getQuotationWithImages(qSales),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('Cannot access quotations belonging to others'),
            ),
          ),
        );
        expect(
          () => repo.saveQuotation(qSales),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('Cannot modify quotations belonging to others'),
            ),
          ),
        );
      },
    );

    test(
      '7. Duplicate rejects a foreign owner before cached images are read',
      () async {
        final trackingCache = TrackingSembastQuotationRepository();
        final duplicateRepo = DuplicateTestQuotationRepository(
          trackingCache,
          locator.supabaseService,
        );
        final foreignQuotation = createTestQuotation(
          salespersonId: 'SALES-001',
        );

        await expectLater(
          duplicateRepo.duplicateQuotation(foreignQuotation),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('Cannot duplicate quotations belonging to others'),
            ),
          ),
        );

        expect(trackingCache.imageReadCount, 0);
        expect(duplicateRepo.saveCount, 0);
      },
    );

    test('8. Duplicate works for the current owner', () async {
      final trackingCache = TrackingSembastQuotationRepository();
      final duplicateRepo = DuplicateTestQuotationRepository(
        trackingCache,
        locator.supabaseService,
      );
      final source = createTestQuotation();

      final duplicated = await duplicateRepo.duplicateQuotation(source);

      expect(trackingCache.imageReadCount, 1);
      expect(duplicateRepo.saveCount, 1);
      expect(duplicated.id, 'DUPLICATED-QUOTATION');
      expect(duplicated.quotationNumber, 'DRAFT-DUPLICATE');
      expect(duplicated.salespersonId, 'ADMIN-001');
      expect(duplicated.status, QuotationStatus.draft);
      expect(duplicateRepo.saveInput?.baseQuotationId, isNull);
      expect(duplicateRepo.saveInput?.revisionNo, 0);
    });

    for (final revisionNo in [1, 2]) {
      test(
        'Duplicate R$revisionNo resets revision identity before save',
        () async {
          final trackingCache = TrackingSembastQuotationRepository();
          final duplicateRepo = DuplicateTestQuotationRepository(
            trackingCache,
            locator.supabaseService,
          );
          final source = createTestQuotation().copyWith(
            id: 'REVISION-$revisionNo',
            quotationNumber: 'QT-AN-0027-26',
            baseQuotationId: 'ORIGINAL',
            revisionNo: revisionNo,
            customerNotes: 'R$revisionNo snapshot',
          );

          final duplicated = await duplicateRepo.duplicateQuotation(source);

          expect(duplicateRepo.saveCount, 1);
          expect(duplicateRepo.saveInput?.id, isEmpty);
          expect(duplicateRepo.saveInput?.quotationNumber, isEmpty);
          expect(duplicateRepo.saveInput?.baseQuotationId, isNull);
          expect(duplicateRepo.saveInput?.revisionNo, 0);
          expect(
            duplicateRepo.saveInput?.customerNotes,
            'R$revisionNo snapshot',
          );
          expect(duplicated.id, 'DUPLICATED-QUOTATION');
          expect(duplicated.revisionNo, 0);
          expect(duplicated.baseQuotationId, isNull);
        },
      );
    }

    test('9. Revision creation fails clearly while offline', () async {
      repo.overrideIsConnected = false;
      final draft = createTestQuotation().copyWith(
        baseQuotationId: 'source-id',
        revisionNo: 1,
      );

      await expectLater(
        repo.createRevision('source-id', draft),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('require a server connection for atomic numbering'),
          ),
        ),
      );
    });
  });
}
