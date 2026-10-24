import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../data/farms_providers.dart';
import '../domain/plot.dart';
import 'farm_display.dart';

class PlotDetailPage extends ConsumerWidget {
  const PlotDetailPage({required this.plotId, super.key});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<Plot> plot = ref.watch(plotProvider(plotId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(strings.plotDetailsTitle),
        actions: <Widget>[
          if (plot.value != null)
            PopupMenuButton<String>(
              key: const Key('plot_actions'),
              icon: const Icon(Icons.more_vert),
              onSelected: (String value) {
                if (value == 'edit') {
                  context.go('/plots/$plotId/edit');
                } else {
                  _confirmDelete(context, ref, strings, plot.value!);
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
        child: plot.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (Object error, StackTrace stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    strings.plotNotFound,
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextButton(
                    key: const Key('plot_detail_retry'),
                    label: strings.retry,
                    onPressed: () => ref.invalidate(plotProvider(plotId)),
                  ),
                ],
              ),
            ),
          ),
          data: (Plot data) => ListView(
            key: const Key('plot_detail_scroll'),
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
                    Text(data.name, style: AppTextStyles.title),
                    if (data.areaHa != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        formatAreaHa(data.areaHa!),
                        key: const Key('plot_detail_area'),
                        style: AppTextStyles.body,
                      ),
                    ],
                    if (data.soilType != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${strings.plotSoilLabel} : ${data.soilType!.label}',
                        style: AppTextStyles.body,
                      ),
                    ],
                    if (data.irrigation != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${strings.plotIrrigationLabel} : ${data.irrigation!.label}',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ComingSoonSection(
                title: strings.plotCyclesTitle,
                message: strings.comingSoon,
              ),
              const SizedBox(height: AppSpacing.md),
              _ComingSoonSection(
                title: strings.plotDiagnosticsTitle,
                message: strings.comingSoon,
              ),
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
    Plot plot,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.plotDeleteTitle),
          content: Text(strings.plotDeleteMessage),
          actions: <Widget>[
            AppTextButton(
              key: const Key('plot_delete_cancel'),
              label: strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('plot_delete_confirm'),
              label: strings.farmDelete,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref
          .read(farmPlotsProvider(plot.farmId).notifier)
          .deletePlot(plot.id);
      if (context.mounted) {
        context.pop();
      }
    }
  }
}

class _ComingSoonSection extends StatelessWidget {
  const _ComingSoonSection({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
