import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/language_controller.dart';
import 'core/router/app_router.dart';
import 'design_system/theme.dart';

Future<void> main() async {
  AppConfig.validate(isRelease: kReleaseMode, url: AppConfig.apiBaseUrl);
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const SmartAgriApp(),
    ),
  );
}

class SmartAgriApp extends ConsumerWidget {
  const SmartAgriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
