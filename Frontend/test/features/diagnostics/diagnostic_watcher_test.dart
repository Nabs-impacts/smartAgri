import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostic_watcher.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:dio/dio.dart';

Diagnostic diagnosticWith(DiagnosticStatus status) {
  return Diagnostic(
    id: 'diag-1',
    status: status,
    createdAt: DateTime.utc(2026, 10, 24, 10),
  );
}

class SequenceDiagnosticsRepository extends DiagnosticsRepository {
  SequenceDiagnosticsRepository(this.responses) : super(dio: Dio());

  final List<Object> responses;
  int calls = 0;

  @override
  Future<Diagnostic> get(String id) async {
    final int index = calls < responses.length ? calls : responses.length - 1;
    final Object item = responses[index];
    calls++;
    if (item is ApiException) {
      throw item;
    }
    return item as Diagnostic;
  }
}

class FakeScheduler {
  DateTime current = DateTime.utc(2026, 10, 24, 10);
  final List<Duration> waits = <Duration>[];
  Future<void> Function(Duration duration)? onWait;

  Future<void> wait(Duration duration) async {
    waits.add(duration);
    current = current.add(duration);
    await onWait?.call(duration);
  }

  DiagnosticScheduler get scheduler =>
      DiagnosticScheduler(wait: wait, now: () => current);
}

void main() {
  test('loads immediately and stops on each terminal status', () async {
    for (final DiagnosticStatus status in <DiagnosticStatus>[
      DiagnosticStatus.done,
      DiagnosticStatus.needsReview,
      DiagnosticStatus.failed,
    ]) {
      final SequenceDiagnosticsRepository repository =
          SequenceDiagnosticsRepository(<Object>[diagnosticWith(status)]);
      final FakeScheduler scheduler = FakeScheduler();
      final DiagnosticWatcher watcher = DiagnosticWatcher(
        repository: repository,
        diagnosticId: 'diag-1',
        scheduler: scheduler.scheduler,
      );
      final List<DiagnosticStatus> updates = <DiagnosticStatus>[];

      final DiagnosticWatchOutcome outcome = await watcher.run(
        onUpdate: (Diagnostic diagnostic) => updates.add(diagnostic.status),
      );

      expect(repository.calls, 1);
      expect(scheduler.waits, isEmpty);
      expect(updates, <DiagnosticStatus>[status]);
      expect(outcome.timedOut, isFalse);
      expect(outcome.diagnostic?.status, status);
    }
  });

  test('polls with 2, 4, 8 and then 10 second waits', () async {
    final SequenceDiagnosticsRepository repository =
        SequenceDiagnosticsRepository(<Object>[
          diagnosticWith(DiagnosticStatus.processing),
          diagnosticWith(DiagnosticStatus.done),
        ]);
    final FakeScheduler scheduler = FakeScheduler();
    final DiagnosticWatcher watcher = DiagnosticWatcher(
      repository: repository,
      diagnosticId: 'diag-1',
      scheduler: scheduler.scheduler,
    );

    final DiagnosticWatchOutcome outcome = await watcher.run();

    expect(repository.calls, 2);
    expect(scheduler.waits, const <Duration>[Duration(seconds: 2)]);
    expect(outcome.diagnostic?.status, DiagnosticStatus.done);
    expect(outcome.timedOut, isFalse);
  });

  test('times out after 60 seconds at most and caps the last wait', () async {
    final SequenceDiagnosticsRepository repository =
        SequenceDiagnosticsRepository(<Object>[
          diagnosticWith(DiagnosticStatus.processing),
        ]);
    final FakeScheduler scheduler = FakeScheduler();
    final DiagnosticWatcher watcher = DiagnosticWatcher(
      repository: repository,
      diagnosticId: 'diag-1',
      scheduler: scheduler.scheduler,
    );

    final DiagnosticWatchOutcome outcome = await watcher.run();

    expect(outcome.timedOut, isTrue);
    expect(repository.calls, 8);
    expect(scheduler.waits, const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 10),
      Duration(seconds: 10),
      Duration(seconds: 10),
      Duration(seconds: 10),
      Duration(seconds: 6),
    ]);
    expect(
      scheduler.current.difference(DateTime.utc(2026, 10, 24, 10)),
      const Duration(seconds: 60),
    );
  });

  test('tolerates five consecutive network errors', () async {
    final SequenceDiagnosticsRepository repository =
        SequenceDiagnosticsRepository(<Object>[
          diagnosticWith(DiagnosticStatus.processing),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
          diagnosticWith(DiagnosticStatus.done),
        ]);
    final FakeScheduler scheduler = FakeScheduler();
    final DiagnosticWatcher watcher = DiagnosticWatcher(
      repository: repository,
      diagnosticId: 'diag-1',
      scheduler: scheduler.scheduler,
    );

    final DiagnosticWatchOutcome outcome = await watcher.run();

    expect(outcome.diagnostic?.status, DiagnosticStatus.done);
    expect(outcome.timedOut, isFalse);
    expect(repository.calls, 7);
  });

  test('gives up after six consecutive network errors', () async {
    final SequenceDiagnosticsRepository repository =
        SequenceDiagnosticsRepository(<Object>[
          diagnosticWith(DiagnosticStatus.processing),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
          ApiException.network(),
        ]);
    final FakeScheduler scheduler = FakeScheduler();
    final DiagnosticWatcher watcher = DiagnosticWatcher(
      repository: repository,
      diagnosticId: 'diag-1',
      scheduler: scheduler.scheduler,
    );

    await expectLater(watcher.run(), throwsA(isA<ApiException>()));
    expect(repository.calls, 7);
  });

  test('stops at the next wait when it is stopped', () async {
    final SequenceDiagnosticsRepository repository =
        SequenceDiagnosticsRepository(<Object>[
          diagnosticWith(DiagnosticStatus.processing),
          diagnosticWith(DiagnosticStatus.done),
        ]);
    final FakeScheduler scheduler = FakeScheduler();
    late final DiagnosticWatcher watcher;
    watcher = DiagnosticWatcher(
      repository: repository,
      diagnosticId: 'diag-1',
      scheduler: scheduler.scheduler,
    );
    scheduler.onWait = (Duration duration) async => watcher.stop();

    final DiagnosticWatchOutcome outcome = await watcher.run();

    expect(repository.calls, 1);
    expect(outcome.timedOut, isFalse);
  });
}
