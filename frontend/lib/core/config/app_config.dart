/// Build-time / public client config.
///
/// Pass overrides with:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://utberukprevggeojfvec.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_JMnUF6mKMNsaZmw8vcdpOg_ZoCTz4_T',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'TRADESQUARE_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
