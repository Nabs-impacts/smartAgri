import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_choice_chips.dart';
import '../../../design_system/components/app_progress_bar.dart';
import '../../../design_system/components/app_select_field.dart';
import '../../../design_system/tokens.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/admin_area.dart';
import '../../catalog/domain/crop.dart';
import '../data/stats_repository.dart';
import '../domain/yield_cell.dart';
import 'admin_format.dart';

class AdminYieldsPage extends ConsumerWidget {
  const AdminYieldsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AppLanguage language = ref.watch(languageControllerProvider);
    final YieldsFilter filter = ref.watch(yieldsFilterProvider);
    final AsyncValue<List<YieldCell>> yields = ref.watch(yieldsProvider);
    final List<Crop> crops = ref.watch(cropsProvider).value ?? const <Crop>[];
    final List<AdminArea> regions =
        (ref.watch(adminAreasProvider).value ?? const <AdminArea>[])
            .where((AdminArea area) => area.level == 'region')
            .toList();
    final int currentYear = DateTime.now().year;
    final List<int> years = <int>[
      currentYear,
      currentYear - 1,
      currentYear - 2,
      currentYear - 3,
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(yieldsProvider.future),
          child: ListView(
            key: const Key('admin_yields_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              Text(strings.adminYieldsTitle, style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.xl),
              _filterLabel(strings.adminFilterCrop),
              const SizedBox(height: AppSpacing.xs),
              AppSelectField<int>(
                key: const Key('admin_yields_crop'),
                hintText: strings.adminFilterAll,
                options: crops
                    .map(
                      (Crop crop) => AppSelectOption<int>(
                        value: crop.id,
                        label: crop.localizedName(language),
                      ),
                    )
                    .toList(),
                value: filter.cropId,
                allowEmpty: true,
                emptyLabel: strings.adminFilterAll,
                onChanged: (int? value) =>
                    ref.read(yieldsFilterProvider.notifier).setCrop(value),
              ),
              const SizedBox(height: AppSpacing.md),
              _filterLabel(strings.adminFilterRegion),
              const SizedBox(height: AppSpacing.xs),
              AppSelectField<int>(
                key: const Key('admin_yields_region'),
                hintText: strings.adminFilterAll,
                options: regions
                    .map(
                      (AdminArea region) => AppSelectOption<int>(
                        value: region.id,
                        label: region.name,
                      ),
                    )
                    .toList(),
                value: filter.regionId,
                allowEmpty: true,
                emptyLabel: strings.adminFilterAll,
                onChanged: (int? value) =>
                    ref.read(yieldsFilterProvider.notifier).setRegion(value),
              ),
              const SizedBox(height: AppSpacing.md),
              _filterLabel(strings.adminFilterSeason),
              const SizedBox(height: AppSpacing.xs),
              AppChoiceChips<SeasonType?>(
                value: filter.seasonType,
                options: <AppChoiceOption<SeasonType?>>[
                  AppChoiceOption<SeasonType?>(
                    value: null,
                    label: strings.adminFilterAll,
                  ),
                  AppChoiceOption<SeasonType?>(
                    value: SeasonType.rainy,
                    label: strings.adminSeasonRainy,
                  ),
                  AppChoiceOption<SeasonType?>(
                    value: SeasonType.dry,
                    label: strings.adminSeasonDry,
                  ),
                ],
                onChanged: (SeasonType? value) =>
                    ref.read(yieldsFilterProvider.notifier).setSeason(value),
              ),
              const SizedBox(height: AppSpacing.md),
              _filterLabel(strings.adminFilterYear),
              const SizedBox(height: AppSpacing.xs),
              AppSelectField<int>(
                key: const Key('admin_yields_year'),
                hintText: strings.adminFilterAll,
                options: years
                    .map(
                      (int year) =>
                          AppSelectOption<int>(value: year, label: '$year'),
                    )
                    .toList(),
                value: filter.seasonYear,
                allowEmpty: true,
                emptyLabel: strings.adminFilterAll,
                onChanged: (int? value) =>
                    ref.read(yieldsFilterProvider.notifier).setYear(value),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (yields.isLoading && yields.value == null)
                ..._skeleton()
              else if (yields.hasError && yields.value == null)
                _error(ref, strings, yields.error)
              else if ((yields.value ?? const <YieldCell>[]).isEmpty)
                AppCard(
                  child: Text(
                    strings.adminYieldEmpty,
                    key: const Key('admin_yields_empty'),
                    style: AppTextStyles.body.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._cards(strings, yields.value!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(color: AppColors.muted),
    );
  }

  List<Widget> _cards(AppLocalizations strings, List<YieldCell> cells) {
    final Map<int, double> maxByCrop = <int, double>{};
    for (final YieldCell cell in cells) {
      if (cell.masked) {
        continue;
      }
      final double value = cell.avgYieldKgPerHa ?? 0;
      final double current = maxByCrop[cell.cropId] ?? 0;
      if (value > current) {
        maxByCrop[cell.cropId] = value;
      }
    }
    return <Widget>[
      for (final YieldCell cell in cells) ...<Widget>[
        cell.masked
            ? _maskedCard(strings, cell)
            : _yieldCard(strings, cell, maxByCrop[cell.cropId] ?? 0),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _yieldCard(AppLocalizations strings, YieldCell cell, double maxYield) {
    final double avg = cell.avgYieldKgPerHa ?? 0;
    final double ratio = maxYield <= 0 ? 0 : avg / maxYield;
    final String season = cell.seasonType == SeasonType.rainy
        ? strings.adminSeasonRainy
        : strings.adminSeasonDry;
    return AppCard(
      key: Key(
        'admin_yield_card_${cell.cropId}_${cell.regionId}_${cell.seasonYear}_${cell.seasonType.apiCode}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.adminYieldTitle(cell.cropName, cell.regionName),
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.adminYieldSeason(season, '${cell.seasonYear}'),
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.adminYieldUnit(formatAdminNumber(avg)),
            key: Key('admin_yield_avg_${cell.cropId}_${cell.regionId}'),
            style: AppTextStyles.headline,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            key: Key(
              'admin_yield_bar_${cell.cropId}_${cell.regionId}_${cell.seasonYear}_${cell.seasonType.apiCode}',
            ),
            value: ratio,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            strings.adminYieldMinMax(
              formatAdminNumber(cell.minYieldKgPerHa ?? 0),
              formatAdminNumber(cell.maxYieldKgPerHa ?? 0),
            ),
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.adminYieldCyclesFarmers(
              formatAdminNumber(cell.cycles ?? 0),
              formatAdminNumber(cell.farmers ?? 0),
            ),
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _maskedCard(AppLocalizations strings, YieldCell cell) {
    return Container(
      key: Key(
        'admin_yield_masked_${cell.cropId}_${cell.regionId}_${cell.seasonYear}_${cell.seasonType.apiCode}',
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: AppRadii.cardBorder,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.line, width: AppSizes.border),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.lock_outline,
            color: AppColors.muted,
            size: AppSizes.icon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.adminYieldTitle(cell.cropName, cell.regionName),
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  strings.adminYieldMasked,
                  key: Key(
                    'admin_yield_masked_text_${cell.cropId}_${cell.regionId}',
                  ),
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _skeleton() {
    return <Widget>[
      Container(
        key: const Key('admin_yields_skeleton'),
        height: 160,
        decoration: const BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: AppRadii.cardBorder,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      for (int index = 0; index < 2; index++) ...<Widget>[
        Container(
          height: 160,
          decoration: const BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: AppRadii.cardBorder,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _error(WidgetRef ref, AppLocalizations strings, Object? error) {
    final bool forbidden = error is ApiException && error.statusCode == 403;
    return AppCard(
      child: Column(
        children: <Widget>[
          if (forbidden) ...<Widget>[
            const Icon(
              Icons.lock_outline,
              color: AppColors.muted,
              size: AppSizes.icon,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            forbidden
                ? strings.adminAccessDenied
                : error is ApiException
                ? apiErrorMessage(error, strings)
                : strings.errorGeneric,
            key: forbidden ? const Key('admin_yields_forbidden') : null,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (!forbidden) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: const Key('admin_yields_retry'),
              label: strings.retry,
              onPressed: () => ref.invalidate(yieldsProvider),
            ),
          ],
        ],
      ),
    );
  }
}
