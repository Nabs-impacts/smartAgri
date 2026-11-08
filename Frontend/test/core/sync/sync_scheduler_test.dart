import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/sync/sync_scheduler.dart';
import 'package:smartagri/core/sync/sync_service.dart';

class FakeSyncTimer implements SyncTimer {
  FakeSyncTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() {
    cancelled = true;
  }

  void fire() {
    if (!cancelled) {
      callback();
    }
  }
}

class FakeTimerFactory {
  final List<FakeSyncTimer> timers = <FakeSyncTimer>[];

  SyncTimer create(Duration duration, void Function() callback) {
    final FakeSyncTimer timer = FakeSyncTimer(duration, callback);
    timers.add(timer);
    return timer;
  }

  FakeSyncTimer active(Duration duration) {
    return timers.lastWhere(
      (FakeSyncTimer timer) => timer.duration == duration && !timer.cancelled,
    );
  }

  bool hasActive(Duration duration) {
    return timers.any(
      (FakeSyncTimer timer) => timer.duration == duration && !timer.cancelled,
    );
  }
}

class SchedulerHarness {
  SchedulerHarness({
    required this.scheduler,
    required this.timerFactory,
    required this.connectivity,
    required this.enqueues,
    required this.clock,
    required this.syncs,
  });

  final SyncScheduler scheduler;
  final FakeTimerFactory timerFactory;
  final StreamController<bool> connectivity;
  final StreamController<void> enqueues;
  final DateTime Function() clock;
  final List<int> syncs;

  int get syncCount => syncs.first;

  Future<void> close() async {
    scheduler.dispose();
    await connectivity.close();
    await enqueues.close();
  }
}

SchedulerHarness buildHarness({bool active = true, DateTime? currentTime}) {
  final FakeTimerFactory timerFactory = FakeTimerFactory();
  final StreamController<bool> connectivity =
      StreamController<bool>.broadcast();
  final StreamController<void> enqueues = StreamController<void>.broadcast();
  DateTime clock() => currentTime ?? DateTime.utc(2026, 11, 8, 10);
  final List<int> syncs = <int>[0];
  final SchedulerHarness harness = SchedulerHarness(
    scheduler: SyncScheduler(
      syncNow: () async {
        syncs[0]++;
        return SyncResult.none;
      },
      isActive: () => active,
      connectivity: () => connectivity.stream,
      enqueues: enqueues.stream,
      now: clock,
      timerFactory: timerFactory.create,
    ),
    timerFactory: timerFactory,
    connectivity: connectivity,
    enqueues: enqueues,
    clock: clock,
    syncs: syncs,
  );
  return harness;
}

void main() {
  test('syncs at startup when connected', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();

    expect(harness.syncCount, 1);
    expect(harness.scheduler.lastSyncStartedAt, harness.clock());
    expect(harness.timerFactory.hasActive(const Duration(minutes: 5)), isTrue);
  });

  test('syncs when the network comes back', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(false);
    await pumpEventQueue();
    expect(harness.syncCount, 0);

    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);

    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);
  });

  test('syncs on application resume and stops the timer on pause', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);

    harness.scheduler.handleAppPaused();
    expect(harness.timerFactory.hasActive(const Duration(minutes: 5)), isFalse);

    harness.scheduler.handleAppResumed();
    await pumpEventQueue();
    expect(harness.syncCount, 2);
    expect(harness.timerFactory.hasActive(const Duration(minutes: 5)), isTrue);
  });

  test('syncs every five minutes while in the foreground', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);

    harness.timerFactory.active(const Duration(minutes: 5)).fire();
    await pumpEventQueue();

    expect(harness.syncCount, 2);
    expect(harness.timerFactory.hasActive(const Duration(minutes: 5)), isTrue);
  });

  test('debounces enqueues by two seconds', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);

    harness.enqueues.add(null);
    await pumpEventQueue();
    expect(harness.syncCount, 1);
    final FakeSyncTimer first = harness.timerFactory.active(
      const Duration(seconds: 2),
    );

    harness.enqueues.add(null);
    await pumpEventQueue();
    expect(first.cancelled, isTrue);
    expect(harness.syncCount, 1);

    harness.timerFactory.active(const Duration(seconds: 2)).fire();
    await pumpEventQueue();
    expect(harness.syncCount, 2);
  });

  test('cancels timers and subscriptions on sign out', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);

    harness.scheduler.stop();
    expect(
      harness.timerFactory.timers.every(
        (FakeSyncTimer timer) => timer.cancelled,
      ),
      isTrue,
    );

    harness.connectivity.add(true);
    harness.enqueues.add(null);
    await pumpEventQueue();

    expect(harness.syncCount, 1);
  });

  test('syncs again after a stop and a new start', () async {
    final SchedulerHarness harness = buildHarness();
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();
    expect(harness.syncCount, 1);

    harness.scheduler.stop();
    harness.scheduler.start();
    harness.connectivity.add(true);
    await pumpEventQueue();

    expect(harness.syncCount, 2);
  });

  test('never syncs without an active session', () async {
    final SchedulerHarness harness = buildHarness(active: false);
    addTearDown(harness.close);

    harness.scheduler.start();
    harness.connectivity.add(true);
    harness.enqueues.add(null);
    await pumpEventQueue();
    harness.timerFactory.active(const Duration(seconds: 2)).fire();
    await pumpEventQueue();

    expect(harness.syncCount, 0);
  });
}
