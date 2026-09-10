import 'package:flutter/foundation.dart';

/// EagleFlow Supabase environment configuration.
///
/// Replace the placeholder values with the real Project URL and anon key from:
/// Supabase Dashboard → Settings → API
///
/// Do NOT commit real keys to version control. In production, inject these via
/// environment variables or a secrets manager.
class SupabaseConfig {
  SupabaseConfig._();

  /// The Supabase project URL.
  /// Example: 'https://xyzabc.supabase.co'
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: kIsWeb ? 'https://pkpgbpzqauwksixxrlwm.supabase.co' : '',
  );

  /// The public anon key (safe to ship in the client build).
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: kIsWeb ? 'sb_publishable_8OutRAFjB6p83_OA2muE_w_qIg98V44' : '',
  );

  /// Returns true when both [url] and [anonKey] have been provided.
  /// When false the app runs in local-only (Sembast) mode.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
