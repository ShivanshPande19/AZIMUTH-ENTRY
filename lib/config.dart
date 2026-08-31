/// Supabase connection settings.
///
/// Provide these at build/run time so no secrets are hard-coded in the repo:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
///
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
///
/// The anon key is safe to ship in the app — real protection comes from the
/// Row Level Security policies and RPCs defined in supabase/schema.sql.
class AppConfig {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
