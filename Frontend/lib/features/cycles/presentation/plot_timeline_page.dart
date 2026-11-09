import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../catalog/data/catalog_repository.dart';
import '../data/cycles_providers.dart';
import '../domain/cycle.dart';
import '../domain/timeline_entry.dart';
import 'cycle_display.dart';
import 'cycle_format.dart';

class PlotTimelinePage extends ConsumerWidget {
  const PlotTimelinePage({required this.plotId, super.key});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<List<TimelineEntry>> timeline = ref.watch(
      plotTimelineProvider(plotId),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.plotTimelineTitle)),
      body: SafeArea(
        child: timeline.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (Object error, StackTrace stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppErrorBanner(message: strings.errorGeneric),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextButton(
                    key: const Key('timeline_retry'),
                    label: strings.retry,
                    onPressed: () =>
                        ref.invalidate(plotTimelineProvider(plotId)),
                  ),
                ],
              ),
            ),
          ),
          data: (List<TimelineEntry> entries) =>
              _TimelineList(strings: strings, plotId: plotId, entries: entries),
        ),
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.strings,
    required this.plotId,
    required this.entries,
  });

  final AppLocalizations strings;
  final String plotId;
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      Text(
        strings.plotTimelineDiagnosticsHint,
        key: const Key('timeline_diagnostics_hint'),
        style: AppTextStyles.caption.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
    if (entries.isEmpty) {
      children.add(
        AppCard(
          child: Text(
            strings.plotTimelineEmpty,
            key: const Key('timeline_empty'),
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      int? currentYear;
      int? currentMonth;
      for (final TimelineEntry entry in entries) {
        if (entry.date.year != currentYear ||
            entry.date.month != currentMonth) {
          currentYear = entry.date.year;
          currentMonth = entry.date.month;
          children.add(
            Padding(
              padding: EdgeInsets.only(
                top: children.length > 2 ? AppSpacing.lg : 0,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                formatMonthYear(entry.date),
                key: Key('timeline_month_${currentYear}_$currentMonth'),
                style: AppTextStyles.title,
              ),
            ),
          );
        }
        children.add(
          _TimelineRow(strings: strings, plotId: plotId, entry: entry),
        );
        children.add(const SizedBox(height: AppSpacing.md));
      }
    }
    return ListView(
      key: const Key('timeline_scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: children,
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({
    required this.strings,
    required this.plotId,
    required this.entry,
  });

  final AppLocalizations strings;
  final String plotId;
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Cycle> cycles =
        ref.watch(cyclesProvider(plotId)).value ?? <Cycle>[];
    Cycle? cycle;
    for (final Cycle item in cycles) {
      if (item.id == timelineEntryCycleId(entry)) {
        cycle = item;
        break;
      }
    }
    final String? cropName = cycle == null
        ? null
        : ref.watch(cultureNameProvider(cycle.cropId)).value;
    final List<String> details = timelineEntryDetails(strings, entry);
    return InkWell(
      key: Key('timeline_entry_${entry.id}'),
      borderRadius: AppRadii.cardBorder,
      onTap: () => context.go('/cycles/${timelineEntryCycleId(entry)}'),
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
              child: Icon(
                timelineEntryIcon(entry),
                color: AppColors.tertiary,
                size: AppSizes.icon,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    <String>[
                      if (cropName != null && cropName.isNotEmpty) cropName,
                      timelineEntryTypeLabel(strings, entry),
                    ].join(' · '),
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatLongDate(entry.date),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (details.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(details.join(' · '), style: AppTextStyles.body),
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
