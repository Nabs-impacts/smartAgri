import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/config/app_config.dart';

void main() {
  test('accepts the default url outside release mode', () {
    expect(
      () => AppConfig.validate(
        isRelease: false,
        url: AppConfig.defaultApiBaseUrl,
      ),
      returnsNormally,
    );
  });

  test('rejects the default url in release mode', () {
    expect(
      () =>
          AppConfig.validate(isRelease: true, url: AppConfig.defaultApiBaseUrl),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'API_BASE_URL manquante ou invalide pour la production.',
        ),
      ),
    );
  });

  test('rejects a non https url in release mode', () {
    expect(
      () => AppConfig.validate(
        isRelease: true,
        url: 'http://api.smartagri.example/api/v1',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('accepts an https url in release mode', () {
    expect(
      () => AppConfig.validate(
        isRelease: true,
        url: 'https://api.smartagri.example/api/v1',
      ),
      returnsNormally,
    );
  });

  test('exposes the consent version', () {
    expect(AppConfig.consentVersion, '1.0');
  });
}
