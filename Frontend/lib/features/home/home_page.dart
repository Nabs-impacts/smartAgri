import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_controller.dart';
import '../../core/i18n/strings_provider.dart';
import '../../core/network/api_error_messages.dart';
import '../../core/network/api_exception.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_icon_button.dart';
import '../../design_system/components/app_text_button.dart';
import '../../design_system/components/info_text.dart';
import '../../design_system/components/info_tile.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/tokens.dart';
import '../auth/domain/user_profile.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/admin_area.dart';
import '../farms/data/farms_providers.dart';
import '../farms/domain/farm.dart';
import '../farms/presentation/farm_display.dart';
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
    final AsyncValue<List<Farm>> farms = ref.watch(farmsProvider);
    final List<AdminArea> areas =
        ref.watch(adminAreasProvider).value ?? <AdminArea>[];
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
              _farmsSection(context, ref, strings, farms, areas),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('home_diagnostic'),
                  label: strings.homeNewDiagnostic,
                  onPressed: () => context.go('/diagnostic/new'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _farmsSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    AsyncValue<List<Farm>> farms,
    List<AdminArea> areas,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(strings.homeFarmsTitle, style: AppTextStyles.title),
            ),
            AppTextButton(
              key: const Key('home_farms_see_all'),
              label: strings.homeFarmsSeeAll,
              onPressed: () => context.go('/farms'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (farms.isLoading && farms.value == null)
          const AppCard(
            child: SizedBox(
              height: 48,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          )
        else if (farms.hasError && farms.value == null)
          AppCard(
            child: Column(
              children: <Widget>[
                Text(
                  farms.error is ApiException
                      ? apiErrorMessage(farms.error! as ApiException, strings)
                      : strings.errorGeneric,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextButton(
                  key: const Key('home_farms_retry'),
                  label: strings.retry,
                  onPressed: () => ref.read(farmsProvider.notifier).refresh(),
                ),
              ],
            ),
          )
        else if ((farms.value ?? <Farm>[]).isEmpty)
          AppCard(
            child: Column(
              children: <Widget>[
                Text(
                  strings.homeFarmsEmpty,
                  key: const Key('home_farms_empty'),
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    key: const Key('home_farms_add'),
                    label: strings.farmAdd,
                    onPressed: () => context.go('/farms/new'),
                  ),
                ),
              ],
            ),
          )
        else
          for (final Farm farm in farms.value!.take(3)) ...<Widget>[
            _HomeFarmTile(
              farm: farm,
              region: farmRegionName(farm, areas),
              onTap: () => context.go('/farms/${farm.id}'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
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

class _HomeFarmTile extends StatelessWidget {
  const _HomeFarmTile({
    required this.farm,
    required this.region,
    required this.onTap,
  });

  final Farm farm;
  final String? region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('home_farm_${farm.id}'),
      borderRadius: AppRadii.cardBorder,
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.agriculture_outlined,
              color: AppColors.primary,
              size: AppSizes.icon,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(farm.name, style: AppTextStyles.label),
                  if (farm.village != null && farm.village!.isNotEmpty)
                    Text(farm.village!, style: AppTextStyles.caption),
                  if (region != null && region!.isNotEmpty)
                    Text(
                      region!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
