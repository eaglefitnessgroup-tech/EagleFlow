import 'dart:async';

import 'package:eagleflow/app/app.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/domain/app_user.dart';
import 'package:eagleflow/features/authentication/domain/auth_repository.dart';
import 'package:eagleflow/features/authentication/domain/auth_result.dart';
import 'package:eagleflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:eagleflow/features/products/data/sembast_product_repository.dart';
import 'package:eagleflow/features/products/data/supabase_product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/products/presentation/products_screen.dart';
import 'package:eagleflow/features/quotations/data/quotation_repository.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    ServiceLocator.resetForTesting();
    final database = await databaseFactoryMemory.openDatabase(
      'startup_readiness_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    DatabaseService().setDatabaseForTesting(database);
    ServiceLocator().mockAuthRepository = _ImmediateAuthRepository();
  });

  tearDown(() async {
    await DatabaseService().closeAndResetForTesting();
    ServiceLocator.resetForTesting();
  });

  testWidgets(
    'delayed app_users mapping prevents data initialization before business user is ready',
    (tester) async {
      final authRepository = _DelayedAuthRepository();
      final productRepository = _DelayedInitProductRepository();
      final locator = ServiceLocator()
        ..mockAuthRepository = authRepository
        ..mockProductRepository = productRepository
        ..mockQuotationRepository = _ImmediateQuotationRepository();

      final initialization = locator.init();
      try {
        await tester.pumpWidget(const EagleFlowApp());
        await tester.pump();

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(productRepository.initCalls, 0);
        expect(productRepository.getAllCalls, 0);

        authRepository.completeMapping(_user('RESTORED-USER'));
        await tester.pump();
        await tester.pump();

        expect(productRepository.initCalls, 1);
      } finally {
        productRepository.releaseInitialization();
        await initialization;
      }
    },
  );

  testWidgets(
    'restored session does not expose Dashboard as data-ready before repositories finish',
    (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '/dashboard';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      final authRepository = _DelayedAuthRepository();
      final productRepository = _DelayedInitProductRepository();
      final locator = ServiceLocator()
        ..mockAuthRepository = authRepository
        ..mockProductRepository = productRepository
        ..mockQuotationRepository = _ImmediateQuotationRepository();

      final initialization = locator.init();
      try {
        await tester.pumpWidget(const EagleFlowApp());
        authRepository.completeMapping(_user('RESTORED-USER'));
        await tester.pump();
        await tester.pump();

        expect(productRepository.initCalls, 1);
        expect(
          find.byType(DashboardScreen),
          findsNothing,
          reason:
              'Authenticated routing must remain in bootstrap until repository initialization completes.',
        );
        expect(find.byType(SplashScreen), findsOneWidget);
      } finally {
        productRepository.releaseInitialization();
        await initialization;
      }
    },
  );

  testWidgets('Dashboard does not join a pre-auth product load after login', (
    tester,
  ) async {
    final locator = ServiceLocator();
    final repository = _DashboardRaceProductRepository(
      localCache: SembastProductRepository(),
      supabase: locator.supabaseService,
    );
    locator.mockProductRepository = repository;
    locator.mockQuotationRepository = _ImmediateQuotationRepository();

    final preAuthLoad = repository.getAllProducts();
    expect(repository.fetchCount, 1);

    locator.authController.setCurrentUserForTesting(_user('USER-B'));
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();

    repository.preAuthResponse.complete(const []);
    await preAuthLoad;
    repository.authenticatedResponse.complete([
      _productRow(id: 'product-b', code: 'B-001'),
    ]);
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('Products shows loading instead of a genuine empty state', (
    tester,
  ) async {
    final repository = _QueuedUiProductRepository();
    final response = repository.enqueueLoad();
    final locator = ServiceLocator()..mockProductRepository = repository;
    locator.authController.setCurrentUserForTesting(_user('USER-A'));

    final load = locator.productMasterController.loadProducts();
    try {
      await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No products found'), findsNothing);
    } finally {
      if (!response.isCompleted) response.complete(const []);
      await load;
    }
  });

  testWidgets(
    'Products shows genuine empty state after a successful empty load',
    (tester) async {
      final repository = _QueuedUiProductRepository();
      final response = repository.enqueueLoad();
      final locator = ServiceLocator()..mockProductRepository = repository;
      locator.authController.setCurrentUserForTesting(_user('USER-A'));

      final load = locator.productMasterController.loadProducts();
      response.complete(const []);
      await load;

      await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
      await tester.pump();

      expect(find.text('0 Products'), findsOneWidget);
      expect(find.text('No products found'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'Dashboard load failure shows persistent retry instead of zeroes',
    (tester) async {
      final locator = ServiceLocator()
        ..mockProductRepository = _FailingProductRepository()
        ..mockQuotationRepository = _ImmediateQuotationRepository();
      locator.authController.setCurrentUserForTesting(_user('USER-A'));

      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    },
  );
}

class _DelayedAuthRepository implements AuthRepository {
  final Completer<AppUser?> _mapping = Completer<AppUser?>();

  void completeMapping(AppUser? user) {
    if (!_mapping.isCompleted) _mapping.complete(user);
  }

  @override
  Future<AppUser?> getCurrentUser() => _mapping.future;

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

class _ImmediateAuthRepository implements AuthRepository {
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

class _DelayedInitProductRepository implements ProductRepository {
  final Completer<void> _initializationGate = Completer<void>();
  int initCalls = 0;
  int getAllCalls = 0;

  void releaseInitialization() {
    if (!_initializationGate.isCompleted) _initializationGate.complete();
  }

  @override
  Future<void> init() async {
    initCalls++;
    await _initializationGate.future;
  }

  @override
  Future<List<Product>> getAllProducts() async {
    getAllCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DashboardRaceProductRepository extends SupabaseProductRepository {
  _DashboardRaceProductRepository({
    required super.localCache,
    required super.supabase,
  });

  final Completer<List<dynamic>> preAuthResponse = Completer<List<dynamic>>();
  final Completer<List<dynamic>> authenticatedResponse =
      Completer<List<dynamic>>();
  int fetchCount = 0;

  @override
  bool get isConnectedToServer => true;

  @override
  Future<List<dynamic>> fetchProductsFromServer() {
    fetchCount++;
    return fetchCount == 1
        ? preAuthResponse.future
        : authenticatedResponse.future;
  }
}

class _QueuedUiProductRepository implements ProductRepository {
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

class _FailingProductRepository implements ProductRepository {
  @override
  Future<void> init() async {}

  @override
  Future<List<Product>> getAllProducts() async {
    throw StateError('remote product fetch failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImmediateQuotationRepository implements QuotationRepository {
  @override
  Future<List<Quotation>> getAllQuotations() async => const [];

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
