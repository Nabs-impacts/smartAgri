import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics/app_haptics.dart';
import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_controller.dart';
import '../../core/i18n/strings_provider.dart';
import '../../core/network/api_error_messages.dart';
import '../../core/network/api_exception.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_status.dart';
import '../../design_system/app_icons.dart';
import '../../design_system/app_palette.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_count_up.dart';
import '../../design_system/components/app_pressable.dart';
import '../../design_system/components/app_progress_bar.dart';
import '../../design_system/components/app_skeleton.dart';
import '../../design_system/components/app_staggered_entrance.dart';
import '../../design_system/components/app_status_chip.dart';
import '../../design_system/components/app_text_button.dart';
import '../../design_system/components/gonata_logo.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/tokens.dart';
import '../auth/domain/user_profile.dart';
import '../cycles/presentation/cycle_display.dart';
import '../cycles/presentation/cycle_format.dart';
import '../diagnostics/data/diagnostics_history_provider.dart';
import '../diagnostics/domain/diagnostic_summary.dart';
import '../diagnostics/presentation/diagnostic_row.dart';
import '../profile/data/me_repository.dart';
import '../sync/sync_format.dart';
import '../weather/data/weather_repository.dart';
import '../weather/domain/weather.dart';
import 'data/home_providers.dart';
import 'domain/home_overview.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(meProvider);
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AppLanguage language = ref.watch(languageControllerProvider);
    final UserProfile? user = ref.watch(currentUserProvider);
    final Weather weather = ref.watch(weatherProvider);
    final SyncSnapshot sync = SyncSnapshot(
      status: ref.watch(syncStatusControllerProvider),
      pendingCount: ref.watch(pendingCountProvider).value ?? 0,
      failedCount: ref.watch(failedCountProvider).value ?? 0,
      lastSyncAt: ref.watch(lastSyncAtProvider).value,
    );
    final AsyncValue<bool> hasFarms = ref.watch(hasFarmsProvider);
    final AsyncValue<DiagnosticsHistoryState> diagnostics = ref.watch(
      diagnosticsHistoryProvider,
    );
    final String firstName = firstNameFromFullName(
      user?.fullName,
      fallback: strings.homeNameFallback,
    );

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: RefreshIndicator(
          key: const Key('home_refresh'),
          onRefresh: () => _refresh(ref),
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
              _header(context, ref, strings, language, user),
              const SizedBox(height: AppSpacing.xl),
              _greeting(context, strings, firstName),
              const SizedBox(height: AppSpacing.md),
              _syncPill(context, ref, strings, sync),
              const SizedBox(height: AppSpacing.lg),
              _weatherCard(context, strings, weather),
              const SizedBox(height: AppSpacing.xl),
              _diagnosticCard(context, ref, strings),
              const SizedBox(height: AppSpacing.xl),
              _mainSections(context, ref, strings, hasFarms),
              const SizedBox(height: AppSpacing.xl),
              _diagnosticsSection(context, ref, strings, diagnostics),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    try {
      await ref.read(syncRunnerProvider)();
    } catch (_) {}
    ref.invalidate(weatherProvider);
    await Future.wait(<Future<void>>[
      ref.read(meProvider.notifier).refresh(),
      ref.read(diagnosticsHistoryProvider.notifier).refresh(),
    ]);
  }

  Widget _header(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    AppLanguage language,
    UserProfile? user,
  ) {
    final Widget switcher = LanguageSwitcher(
      value: language,
      onChanged: (AppLanguage value) =>
          ref.read(languageControllerProvider.notifier).set(value),
    );
    final Widget profile = _ProfileButton(
      initials: _initials(user?.fullName),
      semanticLabel: strings.homeProfileSemantic,
      onTap: () => context.push('/profile'),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget logo = const GonataLogo.full(
          key: Key('home_logo'),
          width: 120,
        );
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(children: <Widget>[logo, const Spacer(), profile]),
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerRight, child: switcher),
            ],
          );
        }
        return Row(
          children: <Widget>[
            logo,
            const Spacer(),
            switcher,
            const SizedBox(width: AppSpacing.sm),
            profile,
          ],
        );
      },
    );
  }

  Widget _greeting(
    BuildContext context,
    AppLocalizations strings,
    String firstName,
  ) {
    return Semantics(
      label: strings.homeGreetingSemantic(firstName),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.homeGreeting,
              style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  firstName,
                  key: const Key('home_first_name'),
                  maxLines: 1,
                  style: AppTextStyles.displayAccent.copyWith(
                    color: context.palette.secondaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncPill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    SyncSnapshot snapshot,
  ) {
    final bool failed = snapshot.failedCount > 0;
    final String label;
    final IconData icon;
    final Color background;
    final Color foreground;
    if (failed) {
      label = strings.moreSyncFailed(snapshot.failedCount);
      icon = AppIcons.warning;
      background = context.palette.dangerContainer;
      foreground = context.palette.onDangerContainer;
    } else if (snapshot.status == SyncStatus.offline) {
      label = strings.syncOffline;
      icon = AppIcons.offline;
      background = context.palette.warningContainer;
      foreground = context.palette.onWarningContainer;
    } else if (snapshot.status == SyncStatus.syncing) {
      label = strings.homeSyncSyncing;
      icon = AppIcons.sync;
      background = context.palette.primaryContainer;
      foreground = context.palette.onPrimaryContainer;
    } else if (snapshot.pendingCount > 0) {
      label = strings.moreSyncPending(snapshot.pendingCount);
      icon = AppIcons.sync;
      background = context.palette.secondaryContainer;
      foreground = context.palette.onSecondaryContainer;
    } else {
      label = strings.homeSyncUpToDate(
        formatLastSync(strings, snapshot.lastSyncAt, DateTime.now()),
      );
      icon = AppIcons.checkCircle;
      background = context.palette.primaryContainer;
      foreground = context.palette.onPrimaryContainer;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: AppPressable(
        key: const Key('home_sync_pill'),
        borderRadius: AppRadii.pillBorder,
        haptics: AppHapticType.tap,
        semanticLabel: label,
        onTap: failed ? () => context.push('/sync/failed') : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadii.pillBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: foreground, size: AppSizes.smallIcon),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weatherCard(
    BuildContext context,
    AppLocalizations strings,
    Weather weather,
  ) {
    final String temperature = _number(weather.temperatureC);
    return AppCard(
      key: const Key('home_weather_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.palette.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.sun,
                  color: context.palette.secondary,
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
                      key: const Key('home_temperature'),
                      maxLines: 1,
                      style: AppTextStyles.displayAccent.copyWith(
                        color: context.palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      strings.homeWeatherCondition(
                        _number(weather.rainRiskPercent),
                      ),
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _WeatherPill(
                icon: AppIcons.wind,
                label: strings.homeWeatherWind(_number(weather.windKmh)),
                background: context.palette.primaryContainer,
                foreground: context.palette.onPrimaryContainer,
              ),
              _WeatherPill(
                icon: weather.soilStatus == SoilStatus.dry
                    ? AppIcons.sun
                    : AppIcons.leaf,
                label: _soilLabel(strings, weather.soilStatus),
                background: context.palette.secondaryContainer,
                foreground: context.palette.onSecondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppStatusChip(
              label: strings.homeDemoData,
              variant: AppStatusChipVariant.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) {
    final MeData? me = ref.watch(meProvider).value;
    final Quota? quota = _diagnosticQuota(me);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.primary,
        borderRadius: AppRadii.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.homeDiagnosticCardTitle,
            style: AppTextStyles.title.copyWith(
              color: context.palette.onPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            strings.homeDiagnosticCardBody,
            style: AppTextStyles.body.copyWith(
              color: context.palette.onPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: context.palette.onPrimary,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.pillBorder,
              ),
              clipBehavior: Clip.antiAlias,
              child: AppPressable(
                key: const Key('home_diagnostic'),
                borderRadius: AppRadii.pillBorder,
                haptics: AppHapticType.confirm,
                semanticLabel: strings.homeDiagnosticAction,
                onTap: () => context.push('/diagnostic/new'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.buttonCompact,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        strings.homeDiagnosticAction,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          color: context.palette.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (quota != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _quotaLine(context, strings, quota),
          ],
        ],
      ),
    );
  }

  Widget _quotaLine(
    BuildContext context,
    AppLocalizations strings,
    Quota quota,
  ) {
    final Color color = context.palette.onPrimary;
    if (quota.isUnlimited) {
      return Text(
        strings.homeDiagnosticUnlimited,
        key: const Key('home_diagnostic_quota'),
        style: AppTextStyles.caption.copyWith(color: color),
      );
    }
    final int remaining = quota.remaining < 0 ? 0 : quota.remaining;
    return Semantics(
      label: strings.homeDiagnosticRemaining(remaining),
      child: ExcludeSemantics(
        child: Wrap(
          key: const Key('home_diagnostic_quota'),
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: <Widget>[
            Text(
              strings.homeDiagnosticRemainingPrefix,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
            AppCountUp(
              value: remaining,
              format: (num value) => value.round().toString(),
              style: AppTextStyles.label.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              strings.homeDiagnosticRemainingSuffix(remaining),
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainSections(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    AsyncValue<bool> hasFarms,
  ) {
    if (hasFarms.isLoading && !hasFarms.hasValue) {
      return _sectionsSkeleton(context, strings);
    }
    if (hasFarms.value == false) {
      return _welcomeCard(context, strings);
    }
    final AsyncValue<List<ActiveCycleOverview>> activeCycles = ref.watch(
      activeCyclesOverviewProvider,
    );
    final AsyncValue<List<RecentActivityOverview>> activities = ref.watch(
      recentActivitiesProvider,
    );
    final List<ActiveCycleOverview> cycles =
        activeCycles.value ?? const <ActiveCycleOverview>[];
    final List<RecentActivityOverview> recent =
        activities.value ?? const <RecentActivityOverview>[];
    final bool showRecent =
        (activities.isLoading && !activities.hasValue) || recent.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _activeCyclesSection(context, ref, strings, activeCycles),
        if (showRecent) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          _recentActivitiesSection(context, strings, activities, recent),
        ],
        const SizedBox(height: AppSpacing.xl),
        _shortcuts(context, strings, cycles),
      ],
    );
  }

  Widget _sectionsSkeleton(BuildContext context, AppLocalizations strings) {
    final double cardWidth = MediaQuery.sizeOf(context).width * 0.8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(strings.homeActiveCyclesTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: cardWidth,
                child: const SkeletonCard(
                  key: Key('home_cycles_skeleton'),
                  height: 196,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: cardWidth,
                child: const SkeletonCard(height: 196),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonList(count: 2, keyPrefix: 'home_sections_skeleton'),
      ],
    );
  }

  Widget _welcomeCard(BuildContext context, AppLocalizations strings) {
    return AppCard(
      key: const Key('home_welcome'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.homeStartTitle, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(strings.homeStartBody, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('home_start_farm'),
              label: strings.homeStartAction,
              onPressed: () => context.push('/farms/new'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeCyclesSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    AsyncValue<List<ActiveCycleOverview>> activeCycles,
  ) {
    final List<ActiveCycleOverview> cycles =
        activeCycles.value ?? const <ActiveCycleOverview>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(strings.homeActiveCyclesTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        if (activeCycles.isLoading && activeCycles.value == null)
          _cyclesSkeleton(context)
        else if (activeCycles.hasError && activeCycles.value == null)
          AppCard(
            child: Column(
              children: <Widget>[
                Text(
                  activeCycles.error is ApiException
                      ? apiErrorMessage(
                          activeCycles.error! as ApiException,
                          strings,
                        )
                      : strings.errorGeneric,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextButton(
                  key: const Key('home_cycles_retry'),
                  label: strings.retry,
                  onPressed: () => ref.invalidate(activeCyclesOverviewProvider),
                ),
              ],
            ),
          )
        else if (cycles.isEmpty)
          _cyclesEmptyCard(context, strings)
        else
          _cyclesList(context, strings, cycles),
      ],
    );
  }

  Widget _cyclesSkeleton(BuildContext context) {
    final double cardWidth = MediaQuery.sizeOf(context).width * 0.8;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: cardWidth,
            child: const SkeletonCard(
              key: Key('home_cycles_skeleton'),
              height: 196,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(width: cardWidth, child: const SkeletonCard(height: 196)),
        ],
      ),
    );
  }

  Widget _cyclesEmptyCard(BuildContext context, AppLocalizations strings) {
    return AppCard(
      key: const Key('home_cycles_empty'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.homeActiveCyclesEmpty, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('home_cycles_farms'),
              label: strings.homeActiveCyclesSeeFarms,
              onPressed: () => context.go('/farms'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cyclesList(
    BuildContext context,
    AppLocalizations strings,
    List<ActiveCycleOverview> cycles,
  ) {
    final double cardWidth = MediaQuery.sizeOf(context).width * 0.8;
    final DateTime today = DateTime.now();
    return SingleChildScrollView(
      key: const Key('home_active_cycles'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < cycles.length; index++) ...<Widget>[
            SizedBox(
              width: cardWidth,
              child: _ActiveCycleCard(
                cycle: cycles[index],
                strings: strings,
                progressText: cycleProgressText(
                  strings,
                  sowingDate: cycles[index].sowingDate,
                  expectedHarvestDate: cycles[index].expectedHarvestDate,
                  today: today,
                ),
                fraction: cycleProgressFraction(
                  sowingDate: cycles[index].sowingDate,
                  expectedHarvestDate: cycles[index].expectedHarvestDate,
                  today: today,
                ),
                onTap: () => context.push('/cycles/${cycles[index].cycleId}'),
              ),
            ),
            if (index < cycles.length - 1) const SizedBox(width: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _recentActivitiesSection(
    BuildContext context,
    AppLocalizations strings,
    AsyncValue<List<RecentActivityOverview>> activities,
    List<RecentActivityOverview> recent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(strings.homeRecentActivitiesTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        if (activities.isLoading && activities.value == null)
          const SkeletonList(count: 2, keyPrefix: 'home_activities_skeleton')
        else
          AppStaggeredEntrance(
            key: const Key('home_recent_activities'),
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final RecentActivityOverview activity in recent)
                _ActivityRow(
                  activity: activity,
                  strings: strings,
                  onTap: () => context.push('/cycles/${activity.cycleId}'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _shortcuts(
    BuildContext context,
    AppLocalizations strings,
    List<ActiveCycleOverview> cycles,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _ShortcutTile(
            key: const Key('home_shortcut_activity'),
            icon: AppIcons.note,
            label: strings.homeShortcutAddActivity,
            onTap: () => _startActivity(context, strings, cycles),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ShortcutTile(
            key: const Key('home_shortcut_harvest'),
            icon: AppIcons.harvest,
            label: strings.homeShortcutAddHarvest,
            onTap: () => _startHarvest(context, strings, cycles),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ShortcutTile(
            key: const Key('home_shortcut_farm'),
            icon: AppIcons.farm,
            label: strings.homeShortcutNewFarm,
            onTap: () => context.push('/farms/new'),
          ),
        ),
      ],
    );
  }

  void _startActivity(
    BuildContext context,
    AppLocalizations strings,
    List<ActiveCycleOverview> cycles,
  ) {
    if (cycles.isEmpty) {
      _showNoCycleSheet(context, strings);
      return;
    }
    if (cycles.length == 1) {
      context.push('/cycles/${cycles.first.cycleId}/activities/new');
      return;
    }
    _showCyclePicker(
      context,
      strings,
      cycles,
      (String cycleId) => context.push('/cycles/$cycleId/activities/new'),
    );
  }

  void _startHarvest(
    BuildContext context,
    AppLocalizations strings,
    List<ActiveCycleOverview> cycles,
  ) {
    if (cycles.isEmpty) {
      _showNoCycleSheet(context, strings);
      return;
    }
    if (cycles.length == 1) {
      context.push('/cycles/${cycles.first.cycleId}/harvests/new');
      return;
    }
    _showCyclePicker(
      context,
      strings,
      cycles,
      (String cycleId) => context.push('/cycles/$cycleId/harvests/new'),
    );
  }

  void _showNoCycleSheet(BuildContext context, AppLocalizations strings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.homeShortcutNoCycleTitle,
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.homeShortcutNoCycleBody,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  key: const Key('home_no_cycle_farms'),
                  label: strings.homeShortcutGoFarms,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/farms');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCyclePicker(
    BuildContext context,
    AppLocalizations strings,
    List<ActiveCycleOverview> cycles,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Text(
                    strings.homeShortcutChooseCycle,
                    style: AppTextStyles.title,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    itemCount: cycles.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ActiveCycleOverview cycle = cycles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppPressable(
                          key: Key('home_cycle_choice_${cycle.cycleId}'),
                          borderRadius: AppRadii.smallBorder,
                          haptics: AppHapticType.tap,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onSelected(cycle.cycleId);
                          },
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  cycle.cropName,
                                  style: AppTextStyles.label,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${cycle.plotName} · ${cycle.farmName}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _diagnosticsSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    AsyncValue<DiagnosticsHistoryState> diagnostics,
  ) {
    final List<DiagnosticSummary> items =
        diagnostics.value?.items ?? const <DiagnosticSummary>[];
    if (diagnostics.isLoading && diagnostics.value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(strings.diagnosticsLatestTitle, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          const SkeletonList(count: 2, keyPrefix: 'home_diagnostics_skeleton'),
        ],
      );
    }
    if (diagnostics.hasError && diagnostics.value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(strings.diagnosticsLatestTitle, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: <Widget>[
                Text(
                  diagnostics.error is ApiException
                      ? apiErrorMessage(
                          diagnostics.error! as ApiException,
                          strings,
                        )
                      : strings.errorGeneric,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextButton(
                  key: const Key('home_diagnostics_retry'),
                  label: strings.retry,
                  onPressed: () =>
                      ref.read(diagnosticsHistoryProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return const SizedBox.shrink(key: Key('home_diagnostics_absent'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                strings.diagnosticsLatestTitle,
                style: AppTextStyles.title,
              ),
            ),
            AppTextButton(
              key: const Key('home_diagnostics_see_all'),
              label: strings.diagnosticsHistorySeeAll,
              onPressed: () => context.push('/diagnostics'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppStaggeredEntrance(
          key: const Key('home_diagnostics'),
          children: <Widget>[
            for (final DiagnosticSummary summary in items.take(2))
              DiagnosticRow(summary: summary),
          ],
        ),
      ],
    );
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

  String _initials(String? fullName) {
    if (fullName == null) {
      return '';
    }
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Quota? _diagnosticQuota(MeData? me) {
    if (me == null) {
      return null;
    }
    for (final Quota quota in me.quotas) {
      if (quota.metric == 'diagnostics_per_month') {
        return quota;
      }
    }
    return null;
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.initials,
    required this.semanticLabel,
    required this.onTap,
  });

  final String initials;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: const Key('home_profile'),
      borderRadius: AppRadii.pillBorder,
      haptics: AppHapticType.tap,
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Container(
        width: AppSizes.touchTarget,
        height: AppSizes.touchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: initials.isEmpty
            ? Icon(
                AppIcons.profile,
                color: context.palette.onPrimaryContainer,
                size: AppSizes.icon,
              )
            : Text(
                initials,
                key: const Key('home_profile_initials'),
                style: AppTextStyles.label.copyWith(
                  color: context.palette.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _WeatherPill extends StatelessWidget {
  const _WeatherPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.smallIcon, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCycleCard extends StatelessWidget {
  const _ActiveCycleCard({
    required this.cycle,
    required this.strings,
    required this.progressText,
    required this.fraction,
    required this.onTap,
  });

  final ActiveCycleOverview cycle;
  final AppLocalizations strings;
  final String progressText;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: Key('home_cycle_${cycle.cycleId}'),
      borderRadius: AppRadii.cardBorder,
      haptics: AppHapticType.tap,
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              cycle.cropName,
              style: AppTextStyles.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${cycle.plotName} · ${cycle.farmName}',
              style: AppTextStyles.caption.copyWith(
                color: context.palette.muted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppStatusChip(
              label: cycleStatusLabel(strings, cycle.status),
              variant: cycleStatusVariant(cycle.status),
            ),
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(value: fraction, label: progressText),
            const SizedBox(height: AppSpacing.xs),
            Text(progressText, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.strings,
    required this.onTap,
  });

  final RecentActivityOverview activity;
  final AppLocalizations strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: Key('home_activity_${activity.activityId}'),
      borderRadius: AppRadii.cardBorder,
      haptics: AppHapticType.tap,
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                activityTypeIcon(activity.type),
                color: context.palette.primary,
                size: AppSizes.icon,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activityTypeLabel(strings, activity.type),
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.homeActivityCropPlot(
                      activity.cropName,
                      activity.plotName,
                    ),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatLongDate(activity.performedOn),
              style: AppTextStyles.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      borderRadius: AppRadii.cardBorder,
      haptics: AppHapticType.tap,
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: context.palette.primary, size: AppSizes.icon),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: context.palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
