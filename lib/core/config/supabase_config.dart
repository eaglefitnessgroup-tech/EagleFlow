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
    defaultValue: '',
  );

  /// The public anon key (safe to ship in the client build).
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Returns true when both [url] and [anonKey] have been provided.
  /// When false the app runs in local-only (Sembast) mode.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
