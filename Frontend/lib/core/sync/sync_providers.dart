import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../network/network_providers.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';
import '../../features/profile/data/me_repository.dart';
import 'outbox.dart';
import 'sync_scheduler.dart';
import 'sync_service.dart';
import 'sync_status.dart';

class SyncStatusController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  void set(SyncStatus status) {
    state = status;
  }
}

final NotifierProvider<SyncStatusController, SyncStatus>
syncStatusControllerProvider =
    NotifierProvider<SyncStatusController, SyncStatus>(
      SyncStatusController.new,
    );

final Provider<SyncService> syncServiceProvider = Provider<SyncService>((
  Ref ref,
) {
  return SyncService(
    database: ref.watch(appDatabaseProvider),
    dio: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxProvider),
  );
});

typedef SyncRunner = Future<SyncResult> Function();

final Provider<SyncRunner> syncRunnerProvider = Provider<SyncRunner>((Ref ref) {
  final SyncStatusController status = ref.read(
    syncStatusControllerProvider.notifier,
  );
  final SyncService service = ref.watch(syncServiceProvider);
  return () async {
    status.set(SyncStatus.syncing);
    try {
      final SyncResult result = await service.syncNow();
      if (result.error != null) {
        status.set(SyncStatus.error);
      } else {
        status.set(result.offline ? SyncStatus.offline : SyncStatus.idle);
      }
      if (result.error == null && !result.offline) {
        await ref.read(meProvider.notifier).refresh();
      }
      return result;
    } catch (error) {
      status.set(SyncStatus.error);
      rethrow;
    }
  };
});

final StreamProvider<int> pendingCountProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(appDatabaseProvider).pendingCount,
);

final StreamProvider<int> failedCountProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(appDatabaseProvider).failedCount,
);

final StreamProvider<List<PendingChangeRow>> failedChangesProvider =
    StreamProvider<List<PendingChangeRow>>(
      (Ref ref) => ref.watch(appDatabaseProvider).watchFailedChanges(),
    );

final Provider<DateTime Function()> syncClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

final StreamProvider<DateTime?> lastSyncAtProvider = StreamProvider<DateTime?>(
  (Ref ref) => ref
      .watch(appDatabaseProvider)
      .watchMeta(SyncService.lastSyncAtKey)
      .map(
        (String? value) =>
            value == null ? null : DateTime.tryParse(value)?.toUtc(),
      ),
);

final Provider<SyncSnapshot> syncStatusProvider = Provider<SyncSnapshot>((
  Ref ref,
) {
  return SyncSnapshot(
    status: ref.watch(syncStatusControllerProvider),
    pendingCount: ref.watch(pendingCountProvider).value ?? 0,
    failedCount: ref.watch(failedCountProvider).value ?? 0,
    lastSyncAt: ref.watch(lastSyncAtProvider).value,
  );
});

bool _isOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) {
    return false;
  }
  return !results.contains(ConnectivityResult.none);
}

final Provider<Stream<bool> Function()> connectivityFactoryProvider =
    Provider<Stream<bool> Function()>((Ref ref) {
      return () {
        final Connectivity connectivity = Connectivity();
        return (() async* {
          yield _isOnline(await connectivity.checkConnectivity());
          yield* connectivity.onConnectivityChanged.map(_isOnline);
        })();
      };
    });

class _SchedulerLifecycleObserver extends WidgetsBindingObserver {
  _SchedulerLifecycleObserver(this.scheduler);

  final SyncScheduler scheduler;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      scheduler.handleAppResumed();
    } else if (state == AppLifecycleState.paused) {
      scheduler.handleAppPaused();
    }
  }
}

final Provider<SyncScheduler> syncSchedulerProvider = Provider<SyncScheduler>((
  Ref ref,
) {
  final SyncRunner runSync = ref.watch(syncRunnerProvider);
  final Outbox outbox = ref.watch(outboxProvider);
  final SyncScheduler scheduler = SyncScheduler(
    syncNow: runSync,
    isActive: () =>
        ref.read(sessionControllerProvider) == SessionState.authenticated,
    connectivity: ref.watch(connectivityFactoryProvider),
    enqueues: outbox.enqueues,
  );

  ref.listen<SessionState>(sessionControllerProvider, (
    SessionState? previous,
    SessionState next,
  ) {
    if (next == SessionState.authenticated) {
      scheduler.start();
    } else if (next == SessionState.unauthenticated) {
      scheduler.stop();
    }
  });

  if (ref.read(sessionControllerProvider) == SessionState.authenticated) {
    scheduler.start();
  }

  final _SchedulerLifecycleObserver observer = _SchedulerLifecycleObserver(
    scheduler,
  );
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    scheduler.dispose();
  });
  return scheduler;
});
