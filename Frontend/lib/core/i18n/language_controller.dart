import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError('SharedPreferences non fourni'),
    );

class LanguageController extends Notifier<AppLanguage> {
  static const String storageKey = 'app_language';

  @override
  AppLanguage build() {
    final SharedPreferences preferences = ref.watch(sharedPreferencesProvider);
    final String? stored = preferences.getString(storageKey);
    return AppLanguage.values.firstWhere(
      (AppLanguage language) => language.apiCode == stored,
      orElse: () => AppLanguage.fr,
    );
  }

  Future<void> set(AppLanguage language) async {
    state = language;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, language.apiCode);
  }
}

final NotifierProvider<LanguageController, AppLanguage>
languageControllerProvider = NotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);
