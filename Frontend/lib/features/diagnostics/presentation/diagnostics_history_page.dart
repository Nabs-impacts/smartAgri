import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens.dart';
import '../data/diagnostics_history_provider.dart';
import '../domain/diagnostic_summary.dart';
import 'diagnostic_row.dart';

class DiagnosticsHistoryPage extends ConsumerStatefulWidget {
  const DiagnosticsHistoryPage({super.key});

  @override
  ConsumerState<DiagnosticsHistoryPage> createState() =>
      _DiagnosticsHistoryPageState();
}

class _DiagnosticsHistoryPageState
    extends ConsumerState<DiagnosticsHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<DiagnosticsHistoryState> history = ref.watch(
      diagnosticsHistoryProvider,
    );
    final DiagnosticsHistoryState? state = history.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.diagnosticsHistoryTitle)),
      body: SafeArea(
        child: state == null && history.isLoading
            ? _Skeleton()
            : state == null && history.hasError
            ? _ErrorView(error: history.error, onRetry: _refresh)
            : _content(strings, state ?? const DiagnosticsHistoryState()),
      ),
    );
  }

  Widget _content(AppLocalizations strings, DiagnosticsHistoryState state) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('diagnostics_history_scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            AppCard(
              child: Column(
                children: <Widget>[
                  Text(
                    strings.diagnosticsHistoryEmpty,
                    key: const Key('diagnostics_history_empty'),
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      key: const Key('diagnostics_history_new'),
                      label: strings.diagnosticsHistoryNew,
                      onPressed: () => context.go('/diagnostic/new'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final int itemCount = state.items.length + (state.loadingMore ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.metrics.extentAfter < 300) {
          ref.read(diagnosticsHistoryProvider.notifier).loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          key: const Key('diagnostics_history_scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    key: Key('diagnostics_history_loading_more'),
                    width: AppSizes.loadingIndicator,
                    height: AppSizes.loadingIndicator,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.loadingStroke,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            final DiagnosticSummary summary = state.items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DiagnosticRow(
                summary: summary,
                onDelete: () => _confirmDelete(summary),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _refresh() {
    return ref.read(diagnosticsHistoryProvider.notifier).refresh();
  }

  Future<void> _confirmDelete(DiagnosticSummary summary) async {
    final AppLocalizations strings = ref.read(stringsProvider);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.diagnosticDeleteTitle),
          content: Text(strings.diagnosticDeleteMessage),
          actions: <Widget>[
            AppButton(
              key: const Key('diagnostics_delete_cancel'),
              label: strings.cancel,
              variant: AppButtonVariant.outlined,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton(
              key: const Key('diagnostics_delete_confirm'),
              label: strings.diagnosticsHistoryDelete,
              size: AppButtonSize.compact,
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
      await ref.read(diagnosticsHistoryProvider.notifier).delete(summary.id);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error, strings))),
        );
      }
    }
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('diagnostics_history_skeleton'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: <Widget>[
        for (int index = 0; index < 6; index++) ...<Widget>[
          Container(
            height: 104,
            decoration: const BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: AppRadii.cardBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final String message = error is ApiException
        ? apiErrorMessage(error! as ApiException, strings)
        : strings.errorGeneric;
    return ListView(
      key: const Key('diagnostics_history_scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        AppCard(
          child: Column(
            children: <Widget>[
              Text(
                message,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('diagnostics_history_retry'),
                  label: strings.retry,
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
