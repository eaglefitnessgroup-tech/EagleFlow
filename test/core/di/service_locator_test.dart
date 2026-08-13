import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/data/supabase_auth_repository.dart';
import 'package:eagleflow/features/authentication/application/auth_controller.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:eagleflow/features/products/domain/product_repository.dart';
import 'package:eagleflow/features/products/domain/product.dart';

class MockSupabaseService implements SupabaseService {
  bool initializeCalled = false;
  bool shouldThrow = false;
  bool _isConnected = false;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isInitialized => initializeCalled;

  @override
  Future<void> initialize() async {
    if (shouldThrow) throw Exception('Supabase config error');
    initializeCalled = true;
    _isConnected = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProductRepository implements ProductRepository {
  bool initCalled = false;
  bool initCalledAfterSupabase = false;
  final SupabaseService _supabase;

  MockProductRepository(this._supabase);

  @override
  Future<void> init() async {
    initCalled = true;
    if (_supabase.isConnected || _supabase.isInitialized) {
      initCalledAfterSupabase = true;
    }
  }

  @override
  Future<List<Product>> getAllProducts() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final db = await databaseFactoryMemory.openDatabase('test.db');
    DatabaseService().setDatabaseForTesting(db);
  });

  group('ServiceLocator Tests', () {
    test('ServiceLocator is a singleton', () {
      final locator1 = ServiceLocator();
      final locator2 = ServiceLocator();

      expect(identical(locator1, locator2), true);
    });

    test('Auth dependencies are registered and exposed correctly', () {
      final locator = ServiceLocator();

      expect(locator.authRepository, isA<SupabaseAuthRepository>());
      expect(locator.authController, isA<AuthController>());
    });

    test('Auth dependencies follow singleton lifecycle across accesses', () {
      final locator = ServiceLocator();

      final repo1 = locator.authRepository;
      final repo2 = locator.authRepository;
      expect(identical(repo1, repo2), true);

      final controller1 = locator.authController;
      final controller2 = locator.authController;
      expect(identical(controller1, controller2), true);
    });

    test('init() completes without crashing', () async {
      final locator = ServiceLocator();

      await expectLater(locator.init(), completes);
    });

    test('supabaseService is registered and is a SupabaseService', () {
      final locator = ServiceLocator();

      expect(locator.supabaseService, isA<SupabaseService>());
    });

    test('supabaseService follows singleton lifecycle', () {
      final locator = ServiceLocator();

      final s1 = locator.supabaseService;
      final s2 = locator.supabaseService;
      expect(identical(s1, s2), isTrue);
    });

    test(
      'configured + connected startup syncs remote products before initial UI load',
      () async {
        ServiceLocator.resetForTesting();
        final locator = ServiceLocator();
        final mockSupabase = MockSupabaseService();
        final mockRepo = MockProductRepository(mockSupabase);

        locator.mockSupabaseService = mockSupabase;
        locator.mockProductRepository = mockRepo;

        await locator.init();

        expect(
          mockSupabase.initializeCalled,
          isTrue,
          reason: 'Supabase should be initialized',
        );
        expect(
          mockRepo.initCalled,
          isTrue,
          reason: 'Product repo should be initialized',
        );
        expect(
          mockRepo.initCalledAfterSupabase,
          isTrue,
          reason: 'Product repo init must run AFTER Supabase initialization',
        );
      },
    );

    test(
      'Supabase initialization failure still allows local startup',
      () async {
        ServiceLocator.resetForTesting();
        final locator = ServiceLocator();
        final mockSupabase = MockSupabaseService();
        mockSupabase.shouldThrow = true;
        final mockRepo = MockProductRepository(mockSupabase);

        locator.mockSupabaseService = mockSupabase;
        locator.mockProductRepository = mockRepo;

        await expectLater(
          locator.init(),
          completes,
          reason: 'Startup should not crash on Supabase failure',
        );
        expect(
          mockRepo.initCalled,
          isTrue,
          reason: 'Local repositories should still initialize',
        );
      },
    );
  });
}
