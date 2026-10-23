import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';

Future<ProviderContainer> buildContainer() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to French and persists changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = await buildContainer();

    expect(container.read(languageControllerProvider), AppLanguage.fr);

    await container
        .read(languageControllerProvider.notifier)
        .set(AppLanguage.ha);

    expect(container.read(languageControllerProvider), AppLanguage.ha);
    final SharedPreferences preferences = container.read(
      sharedPreferencesProvider,
    );
    expect(preferences.getString('app_language'), 'ha');
  });

  test('reads the persisted language', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_language': 'dje',
    });
    final ProviderContainer container = await buildContainer();

    expect(container.read(languageControllerProvider), AppLanguage.dje);
  });

  test('falls back to French for an unknown value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_language': 'en',
    });
    final ProviderContainer container = await buildContainer();

    expect(container.read(languageControllerProvider), AppLanguage.fr);
  });
}
