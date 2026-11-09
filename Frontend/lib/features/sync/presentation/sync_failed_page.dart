import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';

class SyncFailedPage extends ConsumerWidget {
  const SyncFailedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<List<PendingChangeRow>> changes = ref.watch(
      failedChangesProvider,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.syncFailedTitle)),
      body: SafeArea(
        child: changes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(strings.errorGeneric, style: AppTextStyles.body),
            ),
          ),
          data: (List<PendingChangeRow> rows) =>
              _content(context, ref, strings, rows),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    List<PendingChangeRow> rows,
  ) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            strings.syncFailedEmpty,
            key: const Key('sync_failed_empty'),
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      key: const Key('sync_failed_scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: AppButton(
            key: const Key('sync_failed_retry_all'),
            label: strings.syncRetryAll,
            variant: AppButtonVariant.outlined,
            onPressed: () => _retryAll(ref),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final PendingChangeRow row in rows) ...<Widget>[
          _FailedChangeTile(
            key: Key('sync_failed_${row.entity}_${row.id}'),
            row: row,
            strings: strings,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Future<void> _retryAll(WidgetRef ref) async {
    try {
      await ref.read(outboxProvider).retryAllFailed();
      await ref.read(syncRunnerProvider)();
    } catch (_) {}
  }
}

class _FailedChangeTile extends ConsumerStatefulWidget {
  const _FailedChangeTile({
    required this.row,
    required this.strings,
    super.key,
  });

  final PendingChangeRow row;
  final AppLocalizations strings;

  @override
  ConsumerState<_FailedChangeTile> createState() => _FailedChangeTileState();
}

class _FailedChangeTileState extends ConsumerState<_FailedChangeTile> {
  late final Future<String?> _nameFuture = _loadName();

  Future<String?> _loadName() async {
    final AppDatabase database = ref.read(appDatabaseProvider);
    if (widget.row.entity == 'farm') {
      return (await database.getFarm(widget.row.id))?.name;
    }
    if (widget.row.entity == 'plot') {
      return (await database.getPlot(widget.row.id))?.name;
    }
    return null;
  }

  String _entityLabel() {
    return widget.row.entity == 'farm'
        ? widget.strings.syncEntityFarm
        : widget.strings.syncEntityPlot;
  }

  String _operationLabel() {
    return widget.row.op == 'delete'
        ? widget.strings.syncOperationDelete
        : widget.strings.syncOperationUpsert;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = widget.strings;
    final PendingChangeRow row = widget.row;
    final String error = (row.lastError == null || row.lastError!.isEmpty)
        ? strings.syncUnknownError
        : row.lastError!;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _entityLabel(),
                  style: AppTextStyles.label.copyWith(color: AppColors.muted),
                ),
              ),
              Text(
                _operationLabel(),
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FutureBuilder<String?>(
            future: _nameFuture,
            builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
              final String name = snapshot.data ?? strings.syncDeletedItem;
              return Text(
                name,
                key: Key('sync_failed_name_${row.entity}_${row.id}'),
                style: AppTextStyles.title,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTextStyles.body.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              AppTextButton(
                key: Key('sync_failed_retry_${row.entity}_${row.id}'),
                label: strings.retry,
                onPressed: () => _retry(ref),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppTextButton(
                key: Key('sync_failed_discard_${row.entity}_${row.id}'),
                label: strings.syncDiscard,
                variant: AppTextButtonVariant.muted,
                onPressed: () => _discard(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _retry(WidgetRef ref) async {
    try {
      await ref
          .read(outboxProvider)
          .retryFailed(widget.row.entity, widget.row.id);
      await ref.read(syncRunnerProvider)();
    } catch (_) {}
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final PendingChangeRow row = widget.row;
    final AppLocalizations strings = widget.strings;
    final bool confirmed = await ref
        .read(appDatabaseProvider)
        .hasServerVersion(row.entity, row.id);
    if (!context.mounted) {
      return;
    }
    final String message = row.op == 'delete'
        ? strings.syncDiscardDelete
        : confirmed
        ? strings.syncDiscardConfirmed
        : strings.syncDiscardUnconfirmed;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.syncDiscardTitle),
          content: Text(message),
          actions: <Widget>[
            AppTextButton(
              key: const Key('sync_discard_cancel'),
              label: strings.profileLogoutCancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('sync_discard_confirm'),
              label: strings.syncDiscardConfirm,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (result == true) {
      await ref.read(outboxProvider).discardFailed(row.entity, row.id);
    }
  }
}
