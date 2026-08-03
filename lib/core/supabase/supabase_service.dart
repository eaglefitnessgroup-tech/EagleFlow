import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Manages the Supabase client lifecycle for EagleFlow.
///
/// Responsibilities:
/// - Initialize Supabase once at app startup (no-op when not configured).
/// - Expose [isConnected], [client], and [currentUser] for use in Phase 7+
///   repositories and sync services.
/// - Provide a lightweight [healthCheck] that ping-tests the Supabase project.
///
/// Phase 6 code (Sembast repositories, Auth, Quotation, Stock) is unaffected
/// by this service. It is purely additive infrastructure.
class SupabaseService extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  @visibleForTesting
  static void resetForTesting() {
    _instance = SupabaseService._internal();
  }

  @visibleForTesting
  static SupabaseService resetForTestingAndReturn() {
    _instance = SupabaseService._internal();
    return _instance;
  }

  // ── State ──────────────────────────────────────────────────────────────────
  bool _initialized = false;
  bool _isConnected = false;
  String? _lastError;

  /// True once [initialize] has completed without throwing.
  bool get isInitialized => _initialized;

  /// True when the most recent health-check succeeded.
  bool get isConnected => _isConnected;

  /// The last error message, if any, from initialization or a health-check.
  String? get lastError => _lastError;

  // ── Client access ──────────────────────────────────────────────────────────

  /// Returns the Supabase [SupabaseClient] when the SDK is configured and
  /// initialized. Returns null in local-only mode (no SUPABASE_URL supplied).
  SupabaseClient? get client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// The currently authenticated Supabase Auth [User], or null when signed out
  /// or running in local-only mode.
  ///
  /// Note: this is the Supabase Auth user, not the EagleFlow [AppUser].
  /// Use [ServiceLocator().authController.currentUser] for business-level identity.
  User? get currentUser => client?.auth.currentUser;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Initializes the Supabase SDK.
  ///
  /// - If [SupabaseConfig.isConfigured] is false (no URL / anon key), this
  ///   method returns immediately, leaving [isConnected] false. The app
  ///   operates in Sembast-only mode.
  /// - Safe to call multiple times; subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'SupabaseService: SUPABASE_URL or SUPABASE_ANON_KEY not set. '
        'Running in local-only (Sembast) mode.',
      );
      _initialized = true;
      _isConnected = false;
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
        // Disable debug output in production
        debug: kDebugMode,
      );

      _initialized = true;
      _lastError = null;

      // Run a health check immediately after init
      _isConnected = await _pingSupabase();
    } catch (e) {
      _initialized = true; // Prevent retry loops — mark as attempted
      _isConnected = false;
      _lastError = e.toString();
      debugPrint('SupabaseService: Initialization failed — $_lastError');
    }

    notifyListeners();
  }

  // ── Health check ───────────────────────────────────────────────────────────

  /// Performs a lightweight connectivity check against the Supabase project.
  ///
  /// Attempts a minimal RPC call or a simple REST ping. Updates [isConnected]
  /// and notifies listeners on change.
  ///
  /// Returns true on success, false on any error (network, auth, config).
  Future<bool> healthCheck() async {
    if (!_initialized || !SupabaseConfig.isConfigured) return false;

    final result = await _pingSupabase();
    if (result != _isConnected) {
      _isConnected = result;
      notifyListeners();
    }
    return result;
  }

  /// Internal ping implementation. Uses a minimal REST query on `app_users`
  /// with limit 0 — no rows returned, just tests connectivity + auth plumbing.
  Future<bool> _pingSupabase() async {
    try {
      final c = client;
      if (c == null) return false;
      // head=true returns only headers; no row data transferred.
      await c
          .from('app_users')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }
}
