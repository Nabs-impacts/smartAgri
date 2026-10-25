import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_status_chip.dart';
import '../../../design_system/tokens.dart';
import '../domain/diagnostic_status.dart';
import '../domain/diagnostic_summary.dart';
import '../domain/severity.dart';

String formatDiagnosticDate(DateTime value) {
  return DateFormat('d MMM y, HH:mm', 'fr').format(value);
}

class DiagnosticRow extends ConsumerWidget {
  const DiagnosticRow({required this.summary, this.onDelete, super.key});

  final DiagnosticSummary summary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final String? label = summary.labelName;
    final String title = label == null || label.trim().isEmpty
        ? strings.diagnosticsHistoryUntitled
        : label;
    return InkWell(
      key: Key('diagnostic_row_${summary.id}'),
      borderRadius: AppRadii.cardBorder,
      onTap: () => context.push('/diagnostic/${summary.id}'),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Thumbnail(url: summary.thumbnailUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatDiagnosticDate(summary.createdAt),
                    key: Key('diagnostic_row_date_${summary.id}'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      AppStatusChip(
                        key: Key('diagnostic_row_status_${summary.id}'),
                        label: _statusLabel(strings, summary.status),
                        variant: _statusVariant(summary.status),
                      ),
                      if (summary.severity != null)
                        AppStatusChip(
                          key: Key('diagnostic_row_severity_${summary.id}'),
                          label: _severityLabel(strings, summary.severity!),
                          variant: _severityVariant(summary.severity!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              PopupMenuButton<String>(
                key: Key('diagnostic_row_menu_${summary.id}'),
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.muted,
                  size: AppSizes.icon,
                ),
                onSelected: (String value) {
                  if (value == 'delete') {
                    onDelete!.call();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      strings.diagnosticsHistoryDelete,
                      key: Key('diagnostic_row_delete_${summary.id}'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations strings, DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.done:
        return strings.diagnosticStatusDone;
      case DiagnosticStatus.needsReview:
        return strings.diagnosticStatusNeedsReview;
      case DiagnosticStatus.failed:
        return strings.diagnosticStatusFailed;
      case DiagnosticStatus.pending:
      case DiagnosticStatus.processing:
        return strings.diagnosticStatusInProgress;
    }
  }

  AppStatusChipVariant _statusVariant(DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.done:
        return AppStatusChipVariant.success;
      case DiagnosticStatus.needsReview:
        return AppStatusChipVariant.warning;
      case DiagnosticStatus.failed:
        return AppStatusChipVariant.danger;
      case DiagnosticStatus.pending:
      case DiagnosticStatus.processing:
        return AppStatusChipVariant.neutral;
    }
  }

  String _severityLabel(AppLocalizations strings, Severity severity) {
    switch (severity) {
      case Severity.low:
        return strings.diagnosticSeverityLow;
      case Severity.medium:
        return strings.diagnosticSeverityMedium;
      case Severity.high:
        return strings.diagnosticSeverityHigh;
    }
  }

  AppStatusChipVariant _severityVariant(Severity severity) {
    switch (severity) {
      case Severity.low:
        return AppStatusChipVariant.success;
      case Severity.medium:
        return AppStatusChipVariant.warning;
      case Severity.high:
        return AppStatusChipVariant.danger;
    }
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget child = url == null || url!.trim().isEmpty
        ? const Icon(Icons.eco_outlined, color: AppColors.primary, size: 28)
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.eco_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          );
    return ClipRRect(
      borderRadius: AppRadii.smallBorder,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        color: AppColors.primaryContainer,
        child: child,
      ),
    );
  }
}
