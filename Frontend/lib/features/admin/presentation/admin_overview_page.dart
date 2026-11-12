import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_progress_bar.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';
import '../data/stats_repository.dart';
import '../domain/overview.dart';
import 'admin_format.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<Overview> overview = ref.watch(overviewProvider);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(overviewProvider.future),
          child: ListView(
            key: const Key('admin_overview_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              Text(strings.adminOverviewTitle, style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.xl),
              if (overview.isLoading && overview.value == null)
                ..._skeleton(context)
              else if (overview.hasError && overview.value == null)
                _error(context, ref, strings, overview.error)
              else
                ..._content(context, strings, overview.value!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    AppLocalizations strings,
    Overview overview,
  ) {
    return <Widget>[
      _kpiCard(
        context,
        key: const Key('admin_kpi_active_users'),
        label: strings.adminActiveUsers,
        value: formatAdminNumber(overview.activeUsers30d),
      ),
      const SizedBox(height: AppSpacing.md),
      _kpiCard(
        context,
        key: const Key('admin_kpi_diagnostics'),
        label: strings.adminDiagnostics,
        value: formatAdminNumber(overview.diagnostics30d),
      ),
      const SizedBox(height: AppSpacing.md),
      _kpiCard(
        context,
        key: const Key('admin_kpi_area'),
        label: strings.adminTrackedArea,
        value: strings.adminHectares(formatAdminNumber(overview.trackedAreaHa)),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text(strings.adminAdoption, style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.md),
      AppCard(
        child: Column(
          children: <Widget>[
            for (final RegionAdoption region in overview.adoption)
              _adoptionRow(context, strings, overview.adoption, region),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.shield_outlined,
                  color: context.palette.primary,
                  size: AppSizes.icon,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    strings.adminPrivacyTitle,
                    key: const Key('admin_privacy_title'),
                    style: AppTextStyles.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.adminPrivacyBody,
              key: const Key('admin_privacy_body'),
              style: AppTextStyles.body.copyWith(color: context.palette.muted),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _kpiCard(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
  }) {
    return AppCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.headline),
        ],
      ),
    );
  }

  Widget _adoptionRow(
    BuildContext context,
    AppLocalizations strings,
    List<RegionAdoption> adoption,
    RegionAdoption region,
  ) {
    final int maxUsers = adoption
        .where((RegionAdoption item) => !item.masked)
        .fold<int>(
          0,
          (int max, RegionAdoption item) =>
              (item.users ?? 0) > max ? item.users ?? 0 : max,
        );
    if (region.masked) {
      return Padding(
        key: Key('admin_adoption_${region.regionId}'),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              color: context.palette.muted,
              size: AppSizes.smallIcon,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(region.regionName, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.adminMaskedRegion,
                    key: Key('admin_adoption_masked_${region.regionId}'),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final int users = region.users ?? 0;
    final double ratio = maxUsers <= 0 ? 0 : users / maxUsers;
    return Padding(
      key: Key('admin_adoption_${region.regionId}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(region.regionName, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.adminUsersPlots(
              formatAdminNumber(users),
              formatAdminNumber(region.plots ?? 0),
            ),
            key: Key('admin_adoption_values_${region.regionId}'),
            style: AppTextStyles.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            key: Key('admin_adoption_bar_${region.regionId}'),
            value: ratio,
          ),
        ],
      ),
    );
  }

  List<Widget> _skeleton(BuildContext context) {
    return <Widget>[
      Container(
        key: const Key('admin_overview_skeleton'),
        height: 92,
        decoration: BoxDecoration(
          color: context.palette.inputFill,
          borderRadius: AppRadii.cardBorder,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      for (int index = 0; index < 3; index++) ...<Widget>[
        Container(
          height: 92,
          decoration: BoxDecoration(
            color: context.palette.inputFill,
            borderRadius: AppRadii.cardBorder,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _error(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    Object? error,
  ) {
    final bool forbidden = error is ApiException && error.statusCode == 403;
    return AppCard(
      child: Column(
        children: <Widget>[
          if (forbidden) ...<Widget>[
            Icon(
              Icons.lock_outline,
              color: context.palette.muted,
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
            key: forbidden ? const Key('admin_overview_forbidden') : null,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (!forbidden) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: const Key('admin_overview_retry'),
              label: strings.retry,
              onPressed: () => ref.invalidate(overviewProvider),
            ),
          ],
        ],
      ),
    );
  }
}
