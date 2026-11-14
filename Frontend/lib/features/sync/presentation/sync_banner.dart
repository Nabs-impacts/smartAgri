import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/sync/sync_status.dart';
import '../../../design_system/app_motion.dart';
import '../../../design_system/components/app_status_banner.dart';
import '../../../design_system/tokens.dart';

class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final SyncSnapshot snapshot = ref.watch(syncStatusProvider);
    final Widget? banner = _banner(context, ref, strings, snapshot);
    return AnimatedSize(
      duration: AppMotion.mediumFor(context),
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.mediumFor(context),
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: banner == null
            ? const SizedBox.shrink(key: ValueKey<String>('sync_none'))
            : SafeArea(
                key: ValueKey<Key?>(banner.key),
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    0,
                  ),
                  child: banner,
                ),
              ),
      ),
    );
  }

  Widget? _banner(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    SyncSnapshot snapshot,
  ) {
    if (snapshot.failedCount > 0) {
      return AppStatusBanner(
        key: const Key('sync_banner_failed'),
        tone: AppStatusBannerTone.error,
        message: strings.syncBannerFailed(snapshot.failedCount),
        onTap: () => context.go('/sync/failed'),
      );
    }
    if (snapshot.status == SyncStatus.offline) {
      final String message = snapshot.pendingCount > 0
          ? '${strings.syncOffline} · ${strings.syncPendingBanner(snapshot.pendingCount)}'
          : strings.syncOffline;
      return AppStatusBanner(
        key: const Key('sync_banner_offline'),
        tone: AppStatusBannerTone.warning,
        message: message,
      );
    }
    if (snapshot.status == SyncStatus.error) {
      return AppStatusBanner(
        key: const Key('sync_banner_error'),
        tone: AppStatusBannerTone.error,
        message: strings.syncErrorBanner,
        actionLabel: strings.retry,
        onAction: () => ref.read(syncRunnerProvider)(),
      );
    }
    if (snapshot.status == SyncStatus.syncing && snapshot.pendingCount > 0) {
      return AppStatusBanner(
        key: const Key('sync_banner_syncing'),
        message: strings.syncInProgress,
      );
    }
    if (snapshot.pendingCount > 0) {
      return AppStatusBanner(
        key: const Key('sync_banner_pending'),
        message: strings.syncPendingBanner(snapshot.pendingCount),
      );
    }
    return null;
  }
}
