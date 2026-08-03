// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/core/supabase/supabase_service.dart';
import 'package:eagleflow/core/config/supabase_config.dart';

/// Tests for SupabaseService.
///
/// These tests run without a real Supabase project.  Because SUPABASE_URL and
/// SUPABASE_ANON_KEY are empty in the test environment, [SupabaseConfig.isConfigured]
/// returns false — causing [SupabaseService.initialize] to enter local-only mode.
/// This validates the null-safe startup path that protects Phase 6 functionality.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SupabaseService.resetForTesting();
  });

  // ── Configuration ──────────────────────────────────────────────────────────

  group('SupabaseConfig', () {
    test('isConfigured returns false when url and anonKey are empty', () {
      // In the test environment no --dart-define flags are passed, so both
      // String.fromEnvironment values resolve to the empty-string defaultValue.
      expect(SupabaseConfig.url, isEmpty);
      expect(SupabaseConfig.anonKey, isEmpty);
      expect(SupabaseConfig.isConfigured, isFalse);
    });
  });

  // ── Singleton ──────────────────────────────────────────────────────────────

  group('SupabaseService singleton', () {
    test('factory returns the same instance', () {
      final s1 = SupabaseService();
      final s2 = SupabaseService();
      expect(identical(s1, s2), isTrue);
    });

    test('resetForTesting produces a fresh instance', () {
      final before = SupabaseService();
      SupabaseService.resetForTesting();
      final after = SupabaseService();
      expect(identical(before, after), isFalse);
    });
  });

  // ── Initialization ─────────────────────────────────────────────────────────

  group('SupabaseService.initialize() — local-only mode', () {
    test('completes without throwing', () async {
      final service = SupabaseService();
      await expectLater(service.initialize(), completes);
    });

    test('isInitialized is true after initialize()', () async {
      final service = SupabaseService();
      expect(service.isInitialized, isFalse);
      await service.initialize();
      expect(service.isInitialized, isTrue);
    });

    test('isConnected is false when Supabase is not configured', () async {
      final service = SupabaseService();
      await service.initialize();
      expect(service.isConnected, isFalse);
    });

    test('client returns null in local-only mode', () async {
      final service = SupabaseService();
      await service.initialize();
      expect(service.client, isNull);
    });

    test('currentUser returns null in local-only mode', () async {
      final service = SupabaseService();
      await service.initialize();
      expect(service.currentUser, isNull);
    });

    test('lastError is null after clean local-only initialization', () async {
      final service = SupabaseService();
      await service.initialize();
      expect(service.lastError, isNull);
    });

    test('calling initialize() twice is a no-op (idempotent)', () async {
      final service = SupabaseService();
      await service.initialize();
      // Second call must not throw or change state
      await expectLater(service.initialize(), completes);
      expect(service.isInitialized, isTrue);
    });
  });

  // ── Health check ───────────────────────────────────────────────────────────

  group('SupabaseService.healthCheck()', () {
    test('returns false when not configured', () async {
      final service = SupabaseService();
      await service.initialize();
      final result = await service.healthCheck();
      expect(result, isFalse);
    });

    test('returns false before initialize() is called', () async {
      final service = SupabaseService();
      // Not initialized yet
      final result = await service.healthCheck();
      expect(result, isFalse);
    });

    test('isConnected reflects healthCheck result', () async {
      final service = SupabaseService();
      await service.initialize();
      final result = await service.healthCheck();
      expect(service.isConnected, equals(result));
    });
  });

  // ── Null-safe startup (simulates ServiceLocator.init() catching errors) ────

  group('Null-safe startup', () {
    test('wrapping initialize() in try/catch never throws', () async {
      final service = SupabaseService();
      Object? caught;
      try {
        await service.initialize();
      } catch (e) {
        caught = e;
      }
      expect(caught, isNull);
    });

    test(
      'service remains accessible after failed init (no exception)',
      () async {
        final service = SupabaseService();
        await service.initialize();
        // All accessors remain callable without throwing
        expect(() => service.isConnected, returnsNormally);
        expect(() => service.isInitialized, returnsNormally);
        expect(() => service.client, returnsNormally);
        expect(() => service.currentUser, returnsNormally);
        expect(() => service.lastError, returnsNormally);
      },
    );
  });
}
