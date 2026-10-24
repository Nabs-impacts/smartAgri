import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_controller.dart';
import '../../core/i18n/strings_provider.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_icon_button.dart';
import '../../design_system/components/info_text.dart';
import '../../design_system/components/info_tile.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/tokens.dart';
import '../auth/domain/user_profile.dart';
import '../profile/data/me_repository.dart';
import '../weather/data/weather_repository.dart';
import '../weather/domain/weather.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(meProvider);
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AppLanguage language = ref.watch(languageControllerProvider);
    final UserProfile? user = ref.watch(currentUserProvider);
    final Weather weather = ref.watch(weatherProvider);
    final String firstName = _firstName(user?.fullName);
    final String temperature = _number(weather.temperatureC);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(meProvider.notifier).refresh(),
          child: ListView(
            key: const Key('home_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  LanguageSwitcher(
                    value: language,
                    onChanged: (AppLanguage value) => ref
                        .read(languageControllerProvider.notifier)
                        .set(value),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    key: const Key('home_profile'),
                    icon: Icons.person_outline,
                    tooltip: strings.navProfile,
                    variant: AppIconButtonVariant.dangerOutline,
                    onPressed: () => context.go('/profile'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                strings.homeGreeting,
                style: AppTextStyles.title.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                firstName,
                key: const Key('home_first_name'),
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wb_sunny_outlined,
                            color: AppColors.secondary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '$temperature°',
                                style: AppTextStyles.headline.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                strings.homeWeatherRain(
                                  _number(weather.rainRiskPercent),
                                ),
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                        InfoTile(
                          label: strings.homeWeatherWind(
                            _number(weather.windKmh),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InfoText(_soilLabel(strings, weather.soilStatus)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.homeDemoData,
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('home_diagnostic'),
                  label: strings.homeNewDiagnostic,
                  onPressed: () => context.go('/diagnostic'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return '';
    }
    final String first = fullName.trim().split(RegExp(r'\s+')).first;
    return first.toUpperCase();
  }

  String _number(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _soilLabel(AppLocalizations strings, SoilStatus status) {
    switch (status) {
      case SoilStatus.good:
        return strings.homeWeatherSoilGood;
      case SoilStatus.dry:
        return strings.homeWeatherSoilDry;
      case SoilStatus.wet:
        return strings.homeWeatherSoilWet;
    }
  }
}
