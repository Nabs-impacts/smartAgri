abstract final class AppConfig {
  static const String defaultApiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );

  static const String startRoute = String.fromEnvironment(
    'START_ROUTE',
    defaultValue: '/splash',
  );

  static const String consentVersion = '1.0';

  static const bool diagnosticDemoBanner = bool.fromEnvironment(
    'DIAGNOSTIC_DEMO',
    defaultValue: true,
  );

  static void validate({required bool isRelease, required String url}) {
    if (isRelease &&
        (url == defaultApiBaseUrl || !url.startsWith('https://'))) {
      throw StateError(
        'API_BASE_URL manquante ou invalide pour la production.',
      );
    }
  }
}
