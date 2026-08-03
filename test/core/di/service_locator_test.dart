import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/core/di/service_locator.dart';
import 'package:eagleflow/features/authentication/data/sembast_auth_repository.dart';
import 'package:eagleflow/features/authentication/application/auth_controller.dart';
import 'package:eagleflow/core/database/database_service.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import 'package:sembast/sembast_memory.dart';

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

      expect(locator.authRepository, isA<SembastAuthRepository>());
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
  });
}
