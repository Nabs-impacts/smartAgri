import 'dart:async';

import 'sync_service.dart';

abstract interface class SyncTimer {
  void cancel();
}

typedef SyncTimerFactory = SyncTimer Function(
  Duration duration,
  void Function() callback,
);

class _DartSyncTimer implements SyncTimer {
  _DartSyncTimer(Duration duration, void Function() callback)
    : _timer = Timer(duration, callback);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

SyncTimer _defaultTimerFactory(Duration duration, void Function() callback) {
  return _DartSyncTimer(duration, callback);
}

class SyncScheduler {
  SyncScheduler({
    required this.syncNow,
    required this.isActive,
    required this.connectivity,
    required this.enqueues,
    DateTime Function()? now,
    SyncTimerFactory? timerFactory,
    this.periodicInterval = const Duration(minutes: 5),
    this.enqueueDebounce = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? _defaultTimerFactory;

  final Future<SyncResult> Function() syncNow;
  final bool Function() isActive;
  final Stream<bool> Function() connectivity;
  final Stream<void> enqueues;
  final DateTime Function() _now;
  final SyncTimerFactory _timerFactory;
  final Duration periodicInterval;
  final Duration enqueueDebounce;

  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<void>? _enqueueSubscription;
  SyncTimer? _periodicTimer;
  SyncTimer? _debounceTimer;
  bool _started = false;
  bool _online = false;
  bool _foreground = true;
  DateTime? _lastSyncStartedAt;

  DateTime? get lastSyncStartedAt => _lastSyncStartedAt;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _foreground = true;
    _online = false;
    _connectivitySubscription = connectivity().listen(
      _handleConnectivity,
      onError: (Object error, StackTrace stackTrace) {},
    );
    _enqueueSubscription = enqueues.listen(
      (void _) => _handleEnqueued(),
      onError: (Object error, StackTrace stackTrace) {},
    );
  }

  void stop() {
    _started = false;
    _cancelTimers();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _enqueueSubscription?.cancel();
    _enqueueSubscription = null;
  }

  void dispose() => stop();

  void handleAppResumed() {
    if (!_started) {
      return;
    }
    _foreground = true;
    if (_online && isActive()) {
      _runSync();
      _schedulePeriodic();
    }
  }

  void handleAppPaused() {
    _foreground = false;
    _cancelPeriodic();
  }

  void _handleConnectivity(bool online) {
    final bool wasOnline = _online;
    _online = online;
    if (!online) {
      _cancelPeriodic();
      return;
    }
    if (!wasOnline && _started) {
      _runSync();
      _schedulePeriodic();
    }
  }

  void _handleEnqueued() {
    if (!_started) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = _timerFactory(enqueueDebounce, () {
      _debounceTimer = null;
      if (_canSync) {
        _runSync();
      }
    });
  }

  bool get _canSync => _started && _online && _foreground && isActive();

  void _runSync() {
    if (!_canSync) {
      return;
    }
    _lastSyncStartedAt = _now();
    unawaited(syncNow());
  }

  void _schedulePeriodic() {
    _cancelPeriodic();
    if (!_canSync) {
      return;
    }
    _periodicTimer = _timerFactory(periodicInterval, () {
      _periodicTimer = null;
      if (!_canSync) {
        return;
      }
      _runSync();
      _schedulePeriodic();
    });
  }

  void _cancelPeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _cancelTimers() {
    _cancelPeriodic();
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
