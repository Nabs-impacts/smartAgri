import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/database/database_owner_guard.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/language_controller.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_providers.dart';
import 'core/theme/theme_mode_controller.dart';
import 'design_system/theme.dart';
import 'features/auth/data/consent_sync_service.dart';

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
    ref.watch(consentSyncStartupProvider);
    ref.watch(databaseOwnerGuardProvider);
    ref.watch(syncSchedulerProvider);
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeControllerProvider),
      builder: (BuildContext context, Widget? child) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? AppTheme.darkOverlayStyle
              : AppTheme.lightOverlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
