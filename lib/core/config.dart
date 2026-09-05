/// Build-time configuration (passed with --dart-define, never hard-coded).
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// When Supabase credentials are absent the app runs in demo mode: an
  /// in-memory dataset (sample polling units, teams, submissions) replaces
  /// the backend so the full UI flow can be explored without a project.
  static bool get demoMode => !isConfigured;
}
