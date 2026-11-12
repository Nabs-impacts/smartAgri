import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_status_chip.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../farms/data/farms_providers.dart';
import '../../farms/presentation/farm_display.dart';
import '../data/cycles_providers.dart';
import '../data/cycles_repository.dart';
import '../domain/activity.dart';
import '../domain/cycle.dart';
import '../domain/cycle_calculations.dart';
import '../domain/cycle_exception.dart';
import '../domain/cycle_status.dart';
import '../domain/cycle_summary.dart';
import '../domain/harvest.dart';
import '../domain/timeline_entry.dart';
import 'cycle_display.dart';
import 'cycle_format.dart';

class CycleDetailPage extends ConsumerStatefulWidget {
  const CycleDetailPage({required this.cycleId, super.key});

  final String cycleId;

  @override
  ConsumerState<CycleDetailPage> createState() => _CycleDetailPageState();
}

class _CycleDetailPageState extends ConsumerState<CycleDetailPage> {
  bool _comparisonRequested = false;
  CycleComparison? _comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<Cycle> cycle = ref.watch(cycleProvider(widget.cycleId));
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(strings.plotCyclesTitle),
        actions: <Widget>[
          if (cycle.value != null)
            PopupMenuButton<String>(
              key: const Key('cycle_actions'),
              icon: const Icon(Icons.more_vert),
              onSelected: (String value) {
                if (value == 'edit') {
                  context.go('/cycles/${cycle.value!.id}/edit');
                } else {
                  _confirmDelete(cycle.value!);
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
        child: cycle.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: context.palette.primary),
          ),
          error: (Object error, StackTrace stackTrace) => _NotFoundView(
            strings: strings,
            message: error is CycleDomainException && error.code == 'not_found'
                ? strings.cycleNotFound
                : strings.errorGeneric,
          ),
          data: (Cycle data) {
            _maybeLoadComparison(data);
            return _buildData(context, strings, data);
          },
        ),
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    AppLocalizations strings,
    Cycle cycle,
  ) {
    final String? cropName = ref.watch(cultureNameProvider(cycle.cropId)).value;
    final double? areaHa = ref.watch(plotProvider(cycle.plotId)).value?.areaHa;
    final List<Activity> activities =
        ref.watch(activitiesProvider(cycle.id)).value ?? <Activity>[];
    final List<Harvest> harvests =
        ref.watch(harvestsProvider(cycle.id)).value ?? <Harvest>[];
    final CycleSummary summary = computeSummary(
      cycle,
      areaHa,
      activities,
      harvests,
    );
    final List<TimelineEntry> entries = mergeTimeline(activities, harvests);
    final bool canHarvest =
        cycle.status == CycleStatus.planned ||
        cycle.status == CycleStatus.growing;
    return ListView(
      key: const Key('cycle_detail_scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: <Widget>[
        _CycleHeader(
          strings: strings,
          cycle: cycle,
          cropName: cropName ?? cycle.cropId.toString(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            if (cycle.status == CycleStatus.planned)
              AppButton(
                key: const Key('cycle_start'),
                label: strings.cycleStart,
                size: AppButtonSize.compact,
                onPressed: () => _changeStatus(CycleStatus.growing),
              ),
            if (cycle.status == CycleStatus.growing)
              AppButton(
                key: const Key('cycle_fail'),
                label: strings.cycleFail,
                size: AppButtonSize.compact,
                variant: AppButtonVariant.outlined,
                onPressed: _confirmFail,
              ),
            if (canHarvest)
              AppButton(
                key: const Key('cycle_add_harvest'),
                label: strings.cycleAddHarvest,
                size: AppButtonSize.compact,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.go('/cycles/${cycle.id}/harvests/new'),
              ),
            AppButton(
              key: const Key('cycle_add_activity'),
              label: strings.cycleAddActivity,
              size: AppButtonSize.compact,
              variant: AppButtonVariant.outlined,
              onPressed: () => context.go('/cycles/${cycle.id}/activities/new'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(strings.cycleSummaryTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        CycleSummaryCard(strings: strings, summary: summary),
        if (_comparison?.averageYieldKgPerHa != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.cycleComparison(
              formatKgPerHa(_comparison!.averageYieldKgPerHa!),
              _comparison!.sampleSize,
            ),
            key: const Key('cycle_comparison'),
            style: AppTextStyles.caption.copyWith(color: context.palette.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(strings.cycleJournalTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          AppCard(
            child: Text(
              strings.cycleJournalEmpty,
              key: const Key('cycle_journal_empty'),
              style: AppTextStyles.body.copyWith(color: context.palette.muted),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final TimelineEntry entry in entries) ...<Widget>[
            _JournalTile(
              strings: strings,
              entry: entry,
              onTap: () => _openEntry(entry),
              onDelete: () => _confirmDeleteEntry(cycle, entry),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  void _maybeLoadComparison(Cycle cycle) {
    if (_comparisonRequested) {
      return;
    }
    _comparisonRequested = true;
    unawaited(() async {
      try {
        final CycleComparison? comparison = await ref
            .read(cyclesRepositoryProvider)
            .fetchComparison(cycle.id);
        if (mounted && comparison?.averageYieldKgPerHa != null) {
          setState(() => _comparison = comparison);
        }
      } catch (_) {}
    }());
  }

  Future<void> _changeStatus(CycleStatus status) async {
    try {
      await ref
          .read(cycleProvider(widget.cycleId).notifier)
          .updateCycle(status: status);
    } on CycleDomainException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _confirmFail() async {
    final AppLocalizations strings = ref.read(stringsProvider);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.cycleFailTitle),
          content: Text(strings.cycleFailMessage),
          actions: <Widget>[
            AppTextButton(
              key: const Key('cycle_fail_cancel'),
              label: strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('cycle_fail_confirm'),
              label: strings.cycleFail,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _changeStatus(CycleStatus.failed);
    }
  }

  Future<void> _confirmDelete(Cycle cycle) async {
    final AppLocalizations strings = ref.read(stringsProvider);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.cycleDeleteTitle),
          content: Text(strings.cycleDeleteMessage),
          actions: <Widget>[
            AppTextButton(
              key: const Key('cycle_delete_cancel'),
              label: strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('cycle_delete_confirm'),
              label: strings.farmDelete,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(cycleProvider(widget.cycleId).notifier).deleteCycle();
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/plots/${cycle.plotId}');
      }
    } on CycleDomainException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _confirmDeleteEntry(Cycle cycle, TimelineEntry entry) async {
    final AppLocalizations strings = ref.read(stringsProvider);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.cycleJournalDeleteTitle),
          content: Text(strings.cycleJournalDeleteMessage),
          actions: <Widget>[
            AppTextButton(
              key: const Key('journal_delete_cancel'),
              label: strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('journal_delete_confirm'),
              label: strings.farmDelete,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      if (entry is ActivityTimelineEntry) {
        await ref
            .read(activitiesProvider(cycle.id).notifier)
            .deleteActivity(entry.activity.id);
      } else if (entry is HarvestTimelineEntry) {
        await ref
            .read(harvestsProvider(cycle.id).notifier)
            .deleteHarvest(entry.harvest.id);
      }
    } on CycleDomainException catch (error) {
      _showMessage(error.message);
    }
  }

  void _openEntry(TimelineEntry entry) {
    if (entry is ActivityTimelineEntry) {
      context.go(
        '/cycles/${widget.cycleId}/activities/${entry.activity.id}/edit',
      );
    } else if (entry is HarvestTimelineEntry) {
      context.go('/cycles/${widget.cycleId}/harvests/${entry.harvest.id}/edit');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.strings, required this.message});

  final AppLocalizations strings;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              key: const Key('cycle_not_found'),
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextButton(
              key: const Key('cycle_not_found_back'),
              label: strings.cycleBack,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({
    required this.strings,
    required this.cycle,
    required this.cropName,
  });

  final AppLocalizations strings;
  final Cycle cycle;
  final String cropName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Text(cropName, style: AppTextStyles.title)),
              const SizedBox(width: AppSpacing.sm),
              AppStatusChip(
                label: cycleStatusLabel(strings, cycle.status),
                variant: cycleStatusVariant(cycle.status),
              ),
            ],
          ),
          if (cycle.variety != null && cycle.variety!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${strings.cycleVarietyLabel} : ${cycle.variety}',
              style: AppTextStyles.body,
            ),
          ],
          if (cycle.season != null && cycle.season!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${strings.cycleSeasonLabel} : ${cycle.season}',
              style: AppTextStyles.body,
            ),
          ],
          if (cycle.sowingDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${strings.cycleSowingDate} : ${formatLongDate(cycle.sowingDate!)}',
              style: AppTextStyles.body,
            ),
          ],
          if (cycle.expectedHarvestDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${strings.cycleExpectedHarvestDate} : '
              '${formatLongDate(cycle.expectedHarvestDate!)}',
              style: AppTextStyles.body,
            ),
          ],
          if (cycle.harvestDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${strings.cycleHarvestDate} : '
              '${formatLongDate(cycle.harvestDate!)}',
              style: AppTextStyles.body,
            ),
          ],
          if (cycle.notes != null && cycle.notes!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              cycle.notes!,
              style: AppTextStyles.body.copyWith(color: context.palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class CycleSummaryCard extends StatelessWidget {
  const CycleSummaryCard({
    required this.strings,
    required this.summary,
    super.key,
  });

  final AppLocalizations strings;
  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final String noValue = strings.cycleSummaryNoValue;
    final bool negative = summary.marginXof < 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SummaryRow(
            label: strings.cycleSummaryArea,
            value: summary.areaHa == null
                ? noValue
                : formatAreaHa(summary.areaHa!),
            valueKey: const Key('summary_area'),
          ),
          _SummaryRow(
            label: strings.cycleSummaryTotalHarvest,
            value: formatKg(summary.totalKg),
            valueKey: const Key('summary_total_kg'),
          ),
          _SummaryRow(
            label: strings.cycleSummaryYield,
            value: summary.yieldKgPerHa == null
                ? noValue
                : formatKgPerHa(summary.yieldKgPerHa!),
            valueKey: const Key('summary_yield'),
          ),
          _SummaryRow(
            label: strings.cycleSummaryCosts,
            value: formatXof(summary.totalCostXof),
            valueKey: const Key('summary_costs'),
          ),
          _SummaryRow(
            label: strings.cycleSummaryRevenue,
            value: formatXof(summary.revenueXof),
            valueKey: const Key('summary_revenue'),
          ),
          _SummaryRow(
            label: strings.cycleSummaryMargin,
            value: formatXof(summary.marginXof),
            valueKey: const Key('summary_margin'),
            valueColor: negative
                ? context.palette.danger
                : context.palette.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            strings.cycleSummaryLocal,
            key: const Key('summary_local'),
            style: AppTextStyles.caption.copyWith(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueKey,
    this.valueColor,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: context.palette.muted),
            ),
          ),
          Text(
            value,
            key: valueKey,
            style: AppTextStyles.label.copyWith(
              color: valueColor ?? context.palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({
    required this.strings,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final AppLocalizations strings;
  final TimelineEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final _JournalContent content = _content();
    return InkWell(
      key: Key('journal_entry_${entry.id}'),
      borderRadius: AppRadii.cardBorder,
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.palette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                content.icon,
                color: context.palette.tertiary,
                size: AppSizes.icon,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(content.title, style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatLongDate(entry.date),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                  if (content.details.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      content.details.join(' · '),
                      style: AppTextStyles.body,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: Key('journal_delete_${entry.id}'),
              tooltip: strings.farmDelete,
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: context.palette.danger,
                size: AppSizes.icon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _JournalContent _content() {
    if (entry is ActivityTimelineEntry) {
      final Activity activity = (entry as ActivityTimelineEntry).activity;
      return _JournalContent(
        icon: activityTypeIcon(activity.type),
        title: activityTypeLabel(strings, activity.type),
        details: <String>[
          if (activity.productName != null && activity.productName!.isNotEmpty)
            activity.productName!,
          if (activity.quantity != null)
            formatQuantity(activity.quantity!, activity.unit),
          if (activity.costXof != null) formatXof(activity.costXof!),
        ],
      );
    }
    final Harvest harvest = (entry as HarvestTimelineEntry).harvest;
    return _JournalContent(
      icon: Icons.agriculture_outlined,
      title: strings.activityTypeHarvest,
      details: <String>[
        formatKg(harvest.quantityKg),
        if (harvest.quality != null)
          '${strings.cycleQuality} : ${harvest.quality!.code}',
        if (harvest.soldKg > 0)
          '${strings.cycleSold} : ${formatKg(harvest.soldKg)}',
      ],
    );
  }
}

class _JournalContent {
  const _JournalContent({
    required this.icon,
    required this.title,
    required this.details,
  });

  final IconData icon;
  final String title;
  final List<String> details;
}
