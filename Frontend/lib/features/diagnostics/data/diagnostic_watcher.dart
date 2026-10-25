import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../domain/diagnostic.dart';
import 'diagnostics_repository.dart';

typedef DiagnosticWait = Future<void> Function(Duration duration);

class DiagnosticScheduler {
  const DiagnosticScheduler({required this.wait, required this.now});

  final DiagnosticWait wait;
  final DateTime Function() now;
}

class DiagnosticWatchOutcome {
  const DiagnosticWatchOutcome({required this.timedOut, this.diagnostic});

  final bool timedOut;
  final Diagnostic? diagnostic;
}

class DiagnosticWatcher {
  DiagnosticWatcher({
    required this.repository,
    required this.diagnosticId,
    DiagnosticScheduler? scheduler,
    this.pollDelays = const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 10),
    ],
    this.timeout = const Duration(seconds: 60),
    this.maxConsecutiveErrors = 5,
  }) : scheduler =
           scheduler ??
           DiagnosticScheduler(
             wait: (Duration duration) => Future<void>.delayed(duration),
             now: DateTime.now,
           );

  final DiagnosticsRepository repository;
  final String diagnosticId;
  final DiagnosticScheduler scheduler;
  final List<Duration> pollDelays;
  final Duration timeout;
  final int maxConsecutiveErrors;

  bool _stopped = false;

  void stop() {
    _stopped = true;
  }

  Future<DiagnosticWatchOutcome> run({
    void Function(Diagnostic diagnostic)? onUpdate,
  }) async {
    _stopped = false;
    final DateTime started = scheduler.now();
    Diagnostic? last;
    int consecutiveErrors = 0;
    int delayIndex = 0;
    bool first = true;
    while (!_stopped) {
      if (!first && scheduler.now().difference(started) >= timeout) {
        return DiagnosticWatchOutcome(timedOut: true, diagnostic: last);
      }
      first = false;
      try {
        final Diagnostic diagnostic = await repository.get(diagnosticId);
        if (_stopped) {
          return DiagnosticWatchOutcome(timedOut: false, diagnostic: last);
        }
        last = diagnostic;
        consecutiveErrors = 0;
        onUpdate?.call(diagnostic);
        if (diagnostic.status.isTerminal) {
          return DiagnosticWatchOutcome(
            timedOut: false,
            diagnostic: diagnostic,
          );
        }
      } on ApiException catch (error) {
        if (!error.isNetwork) {
          rethrow;
        }
        consecutiveErrors++;
        if (consecutiveErrors > maxConsecutiveErrors) {
          rethrow;
        }
      }
      if (_stopped) {
        break;
      }
      final Duration elapsed = scheduler.now().difference(started);
      final Duration remaining = timeout - elapsed;
      if (remaining <= Duration.zero) {
        return DiagnosticWatchOutcome(timedOut: true, diagnostic: last);
      }
      final Duration delay =
          pollDelays[delayIndex < pollDelays.length
              ? delayIndex
              : pollDelays.length - 1];
      delayIndex++;
      await scheduler.wait(delay < remaining ? delay : remaining);
    }
    return DiagnosticWatchOutcome(timedOut: false, diagnostic: last);
  }
}

class DiagnosticWatchState {
  const DiagnosticWatchState({this.diagnostic, this.timedOut = false});

  final Diagnostic? diagnostic;
  final bool timedOut;
}

class DiagnosticWatchController extends AsyncNotifier<DiagnosticWatchState> {
  DiagnosticWatchController(this.diagnosticId);

  final String diagnosticId;
  late DiagnosticWatcher _watcher;

  @override
  DiagnosticWatchState build() {
    _watcher = ref.watch(diagnosticWatcherProvider(diagnosticId));
    ref.onDispose(_watcher.stop);
    unawaited(_run());
    return const DiagnosticWatchState();
  }

  Future<void> _run() async {
    try {
      final DiagnosticWatchOutcome outcome = await _watcher.run(
        onUpdate: (Diagnostic diagnostic) {
          if (ref.mounted) {
            state = AsyncData<DiagnosticWatchState>(
              DiagnosticWatchState(diagnostic: diagnostic),
            );
          }
        },
      );
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<DiagnosticWatchState>(
        DiagnosticWatchState(
          diagnostic: outcome.diagnostic ?? state.value?.diagnostic,
          timedOut: outcome.timedOut,
        ),
      );
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError<DiagnosticWatchState>(error, stackTrace);
      }
    }
  }

  Future<void> resume() async {
    if (state.value?.timedOut != true) {
      return;
    }
    state = AsyncData<DiagnosticWatchState>(
      DiagnosticWatchState(diagnostic: state.value?.diagnostic),
    );
    await _run();
  }
}

final Provider<DiagnosticScheduler> diagnosticSchedulerProvider =
    Provider<DiagnosticScheduler>(
      (Ref ref) => DiagnosticScheduler(
        wait: (Duration duration) => Future<void>.delayed(duration),
        now: DateTime.now,
      ),
    );

final diagnosticWatcherProvider = Provider.family<DiagnosticWatcher, String>(
  (Ref ref, String id) => DiagnosticWatcher(
    repository: ref.watch(diagnosticsRepositoryProvider),
    diagnosticId: id,
    scheduler: ref.watch(diagnosticSchedulerProvider),
  ),
);

final diagnosticWatchProvider = AsyncNotifierProvider.autoDispose
    .family<DiagnosticWatchController, DiagnosticWatchState, String>(
      DiagnosticWatchController.new,
      retry: (int retryCount, Object error) => null,
    );
