import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_language.dart';
import 'app_localizations.dart';
import 'language_controller.dart';

final Provider<AppLocalizations> stringsProvider = Provider<AppLocalizations>((
  Ref ref,
) {
  final AppLanguage language = ref.watch(languageControllerProvider);
  return lookupAppLocalizations(Locale(language.apiCode));
});
