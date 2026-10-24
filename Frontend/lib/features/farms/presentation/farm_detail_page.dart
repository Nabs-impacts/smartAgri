import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/admin_area.dart';
import '../data/farms_providers.dart';
import '../domain/farm.dart';
import '../domain/plot.dart';
import 'farm_display.dart';

class FarmDetailPage extends ConsumerWidget {
  const FarmDetailPage({required this.farmId, super.key});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<List<Farm>> farms = ref.watch(farmsProvider);
    Farm? farm;
    for (final Farm item in farms.value ?? <Farm>[]) {
      if (item.id == farmId) {
        farm = item;
        break;
      }
    }
    if (farm == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(strings.farmDetailsTitle)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: farms.isLoading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          farms.hasError
                              ? strings.errorGeneric
                              : strings.farmNotFound,
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextButton(
                          key: const Key('farm_detail_retry'),
                          label: strings.retry,
                          onPressed: () =>
                              ref.read(farmsProvider.notifier).refresh(),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    final Farm currentFarm = farm;
    final List<AdminArea> areas =
        ref.watch(adminAreasProvider).value ?? <AdminArea>[];
    final AsyncValue<List<Plot>> plots = ref.watch(
      farmPlotsProvider(currentFarm.id),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(currentFarm.name),
        actions: <Widget>[
          PopupMenuButton<String>(
            key: const Key('farm_actions'),
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'edit') {
                context.go('/farms/${currentFarm.id}/edit');
              } else {
                _confirmDelete(context, ref, strings, currentFarm);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(strings.farmEdit),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(strings.farmDelete),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(farmsProvider.notifier).refresh();
            await ref
                .read(farmPlotsProvider(currentFarm.id).notifier)
                .refresh();
          },
          child: ListView(
            key: const Key('farm_detail_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(currentFarm.name, style: AppTextStyles.title),
                    if (currentFarm.village != null &&
                        currentFarm.village!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(currentFarm.village!, style: AppTextStyles.body),
                    ],
                    if (farmRegionName(currentFarm, areas) != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        farmRegionName(currentFarm, areas)!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(strings.plotsTitle, style: AppTextStyles.title),
                  ),
                  AppTextButton(
                    key: const Key('farm_add_plot'),
                    label: strings.plotAdd,
                    onPressed: () =>
                        context.go('/farms/${currentFarm.id}/plots/new'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (plots.isLoading && plots.value == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (plots.hasError && plots.value == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AppErrorBanner(
                      message: plots.error is ApiException
                          ? apiErrorMessage(
                              plots.error! as ApiException,
                              strings,
                            )
                          : strings.errorGeneric,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: AppTextButton(
                        key: const Key('farm_plots_retry'),
                        label: strings.retry,
                        onPressed: () => ref
                            .read(farmPlotsProvider(currentFarm.id).notifier)
                            .refresh(),
                      ),
                    ),
                  ],
                )
              else if ((plots.value ?? <Plot>[]).isEmpty)
                AppCard(
                  child: Text(
                    strings.plotsEmpty,
                    key: const Key('farm_plots_empty'),
                    style: AppTextStyles.body.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final Plot plot in plots.value!) ...<Widget>[
                  _PlotTile(
                    plot: plot,
                    onTap: () => context.go('/plots/${plot.id}'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    Farm farm,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.farmDeleteTitle),
          content: Text(strings.farmDeleteMessage),
          actions: <Widget>[
            AppTextButton(
              key: const Key('farm_delete_cancel'),
              label: strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('farm_delete_confirm'),
              label: strings.farmDelete,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(farmsProvider.notifier).deleteFarm(farm.id);
      if (context.mounted) {
        context.pop();
      }
    }
  }
}

class _PlotTile extends StatelessWidget {
  const _PlotTile({required this.plot, required this.onTap});

  final Plot plot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<String> details = <String>[
      if (plot.areaHa != null) formatAreaHa(plot.areaHa!),
      if (plot.soilType != null) plot.soilType!.label,
      if (plot.irrigation != null) plot.irrigation!.label,
    ];
    return InkWell(
      key: Key('plot_card_${plot.id}'),
      borderRadius: AppRadii.cardBorder,
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.landscape_outlined,
                color: AppColors.tertiary,
                size: AppSizes.icon,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(plot.name, style: AppTextStyles.title),
                  if (details.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      details.join(' · '),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.muted,
              size: AppSizes.icon,
            ),
          ],
        ),
      ),
    );
  }
}
