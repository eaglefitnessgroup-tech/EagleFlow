import 'dart:async';

import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';
import 'package:eagleflow/features/products/application/product_master_controller.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/data/supabase_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/quotations/data/sembast_quotation_repository.dart';
import 'package:eagleflow/features/quotations/data/supabase_quotation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;

  setUp(() async {
    ServiceLocator.resetForTesting();
    database = await databaseFactoryMemory.openDatabase(
      'startup_race_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);
    ServiceLocator().mockAuthRepository = _StaticAuthRepository();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  group('product authentication boundary', () {
    test(
      'fast login must not accept an in-flight pre-auth product result as final data',
      () async {
        final session = _MutableSession();
        final repository = _ControlledSupabaseProductRepository(
          localCache: SembastProductRepository(),
          supabase: ServiceLocator().supabaseService,
          session: session,
        );
        final preAuthResponse = repository.enqueueResponse();
        final authenticatedResponse = repository.enqueueResponse();

        final preAuthLoad = repository.getAllProducts();
        expect(repository.fetchSessions, [null]);

        session.userId = 'USER-B';
        final authenticatedLoad = repository.getAllProducts();

        preAuthResponse.complete(const []);
        await preAuthLoad;

        if (repository.fetchCount >= 2 && !authenticatedResponse.isCompleted) {
          authenticatedResponse.complete([
            _productRow(id: 'product-b', code: 'B-001'),
          ]);
        }
        final authenticatedProducts = await authenticatedLoad;

        expect(
          repository.fetchSessions,
          [null, 'USER-B'],
          reason:
              'Authentication becoming ready must force a new authenticated fetch instead of joining the pre-auth future.',
        );
        expect(authenticatedProducts.map((p) => p.id), contains('product-b'));
      },
    );

    test(
      'authenticated product load does not join the pre-auth active sync',
      () async {
        final session = _MutableSession();
        final repository = _ControlledSupabaseProductRepository(
          localCache: SembastProductRepository(),
          supabase: ServiceLocator().supabaseService,
          session: session,
        );
        final preAuthResponse = repository.enqueueResponse();
        final authenticatedResponse = repository.enqueueResponse();

        final preAuthLoad = repository.getAllProducts();
        session.userId = 'USER-B';
        final authenticatedLoad = repository.getAllProducts();

        preAuthResponse.complete(const []);
        authenticatedResponse.complete([
          _productRow(id: 'product-b', code: 'B-001'),
        ]);

        expect(await preAuthLoad, isEmpty);
        expect((await authenticatedLoad).map((p) => p.id), ['product-b']);
        expect(repository.fetchCount, 2);
        expect(repository.fetchSessions, [null, 'USER-B']);
      },
    );

    test(
      'remote product failure must be surfaced instead of becoming loaded-empty',
      () async {
        final session = _MutableSession()..userId = 'USER-A';
        final repository = _ControlledSupabaseProductRepository(
          localCache: SembastProductRepository(),
          supabase: ServiceLocator().supabaseService,
          session: session,
        );
        final response = repository.enqueueResponse();

        final load = repository.getAllProducts();
        response.completeError(StateError('first fetch failed'));

        await expectLater(load, throwsA(isA<StateError>()));
      },
    );

    test(
      'explicit second product fetch succeeds after first remote failure',
      () async {
        final session = _MutableSession()..userId = 'USER-A';
        final repository = _ControlledSupabaseProductRepository(
          localCache: SembastProductRepository(),
          supabase: ServiceLocator().supabaseService,
          session: session,
        );
        final firstResponse = repository.enqueueResponse();
        final secondResponse = repository.enqueueResponse();

        final firstLoad = repository.getAllProducts();
        firstResponse.completeError(StateError('temporary failure'));
        await expectLater(firstLoad, throwsA(isA<StateError>()));

        final retry = repository.getAllProducts();
        secondResponse.complete([
          _productRow(id: 'recovered', code: 'RECOVERED-1'),
        ]);

        expect((await retry).map((p) => p.id), contains('recovered'));
        expect(repository.fetchCount, 2);
      },
    );

    test(
      'logout then login as another user must reject stale in-flight product data',
      () async {
        final session = _MutableSession()..userId = 'USER-A';
        final repository = _ControlledSupabaseProductRepository(
          localCache: SembastProductRepository(),
          supabase: ServiceLocator().supabaseService,
          session: session,
        );
        final userAResponse = repository.enqueueResponse();
        final userBResponse = repository.enqueueResponse();

        final userALoad = repository.getAllProducts();
        session.userId = null;
        session.userId = 'USER-B';
        final userBLoad = repository.getAllProducts();

        userAResponse.complete([_productRow(id: 'product-a', code: 'A-001')]);
        await userALoad;

        if (repository.fetchCount >= 2 && !userBResponse.isCompleted) {
          userBResponse.complete([_productRow(id: 'product-b', code: 'B-001')]);
        }
        final productsVisibleToB = await userBLoad;

        expect(
          repository.fetchSessions,
          ['USER-A', 'USER-B'],
          reason: 'The new session must not join USER-A\'s active request.',
        );
        expect(productsVisibleToB.map((p) => p.id), ['product-b']);
      },
    );
  });

  test(
    'quotation load after login must not remain empty because pre-auth init is active',
    () async {
      final locator = ServiceLocator();
      locator.authController.setCurrentUserForTesting(null);

      final repository = _ControlledSupabaseQuotationRepository(
        SembastQuotationRepository(),
        locator.supabaseService,
      );
      final preAuthResponse = repository.enqueueResponse();
      final authenticatedResponse = repository.enqueueResponse();

      final preAuthInit = repository.init();
      expect(repository.fetchUserIds, [null]);

      locator.authController.setCurrentUserForTesting(_user('USER-B'));
      final authenticatedLoad = repository.getAllQuotations();

      preAuthResponse.complete(const []);
      await preAuthInit;

      if (repository.fetchCount >= 2 && !authenticatedResponse.isCompleted) {
        authenticatedResponse.complete([
          _quotationRow(id: 'quote-b', salespersonId: 'USER-B'),
        ]);
      }
      final quotations = await authenticatedLoad;

      expect(
        repository.fetchUserIds,
        [null, 'USER-B'],
        reason:
            'Authenticated quotation loading must not join an init request that ran without a business user.',
      );
      expect(quotations.map((q) => q.id), contains('quote-b'));
    },
  );

  test(
    'ProductMasterController keeps the newer result when an older load completes last',
    () async {
      final repository = _QueuedProductRepository();
      final olderResponse = repository.enqueueLoad();
      final newerResponse = repository.enqueueLoad();
      final controller = ProductMasterController(repository);

      final olderLoad = controller.loadProducts();
      final newerLoad = controller.loadProducts();

      newerResponse.complete([_product(id: 'newer', code: 'NEW-1')]);
      await newerLoad;
      expect(controller.products.single.id, 'newer');

      olderResponse.complete([_product(id: 'older', code: 'OLD-1')]);
      await olderLoad;

      expect(
        controller.products.single.id,
        'newer',
        reason: 'An obsolete completion must not overwrite the latest load.',
      );
    },
  );
}

class _MutableSession {
  String? userId;
}

class _StaticAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> getCurrentUser() async => null;

  @override
  Future<AuthResult> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<List<AppUser>> getUsers() async => const [];

  @override
  Future<bool> hasRememberedSession() async => false;

  @override
  Future<void> clearRememberedSession() async {}
}

class _ControlledSupabaseProductRepository extends SupabaseProductRepository {
  _ControlledSupabaseProductRepository({
    required super.localCache,
    required super.supabase,
    required this.session,
  });

  final _MutableSession session;
  final List<Completer<List<dynamic>>> _responses = [];
  final List<String?> fetchSessions = [];
  int fetchCount = 0;

  Completer<List<dynamic>> enqueueResponse() {
    final completer = Completer<List<dynamic>>();
    _responses.add(completer);
    return completer;
  }

  @override
  bool get isConnectedToServer => true;

  @override
  Future<List<dynamic>> fetchProductsFromServer() {
    fetchSessions.add(session.userId);
    final response = _responses[fetchCount];
    fetchCount++;
    return response.future;
  }
}

class _ControlledSupabaseQuotationRepository
    extends SupabaseQuotationRepository {
  _ControlledSupabaseQuotationRepository(super.localCache, super.supabase);

  final List<Completer<List<dynamic>>> _responses = [];
  final List<String?> fetchUserIds = [];
  int fetchCount = 0;

  Completer<List<dynamic>> enqueueResponse() {
    final completer = Completer<List<dynamic>>();
    _responses.add(completer);
    return completer;
  }

  @override
  bool get isConnectedToServer => true;

  @override
  Future<List<dynamic>> fetchQuotationsFromServer() {
    fetchUserIds.add(ServiceLocator().authController.currentUser?.id);
    final response = _responses[fetchCount];
    fetchCount++;
    return response.future;
  }
}

class _QueuedProductRepository implements ProductRepository {
  final List<Completer<List<Product>>> _loads = [];
  int _nextLoad = 0;

  Completer<List<Product>> enqueueLoad() {
    final completer = Completer<List<Product>>();
    _loads.add(completer);
    return completer;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Product>> getAllProducts() => _loads[_nextLoad++].future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppUser _user(String id) {
  final now = DateTime(2026, 9, 26);
  return AppUser(
    id: id,
    name: id,
    username: id.toLowerCase(),
    passwordHash: '',
    role: UserRole.sales,
    createdAt: now,
    updatedAt: now,
  );
}

Product _product({required String id, required String code}) {
  final now = DateTime(2026, 9, 26);
  return Product(
    id: id,
    productCode: code,
    name: 'Product $code',
    category: 'Category',
    brand: 'Brand',
    sellingPrice: 100,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> _productRow({required String id, required String code}) {
  final timestamp = DateTime(2026, 9, 26).toUtc().toIso8601String();
  return {
    'id': id,
    'product_code': code,
    'normalized_product_code': code,
    'name': 'Product $code',
    'category': 'Category',
    'brand': 'Brand',
    'selling_price': 100,
    'is_vat_applicable': true,
    'is_active': true,
    'min_stock_level': 0,
    'opening_stock': 0,
    'created_at': timestamp,
    'updated_at': timestamp,
  };
}

Map<String, dynamic> _quotationRow({
  required String id,
  required String salespersonId,
}) {
  final created = DateTime(2026, 9, 26, 10).toUtc();
  return {
    'id': id,
    'quotation_number': 'QT-TEST-1',
    'salesperson_id': salespersonId,
    'customer_name': 'Customer',
    'customer_company': '',
    'customer_phone': '',
    'customer_email': '',
    'project_location': '',
    'delivery_charges': 0,
    'installation_charges': 0,
    'other_charges': 0,
    'overall_discount': 0,
    'vat_percentage': 5,
    'customer_notes': '',
    'internal_notes': '',
    'status': 'draft',
    'created_at': created.toIso8601String(),
    'updated_at': created.toIso8601String(),
    'valid_until': created.add(const Duration(days: 14)).toIso8601String(),
    'expected_delivery': created.add(const Duration(days: 3)).toIso8601String(),
    'quotation_items': const <Map<String, dynamic>>[],
  };
}
