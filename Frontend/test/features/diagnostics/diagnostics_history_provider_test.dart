import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_history_provider.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';

import 'fake_diagnostics_repository.dart';

ProviderContainer buildContainer(FakeDiagnosticsRepository repository) {
  final ProviderContainer container = ProviderContainer(
    overrides: [diagnosticsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('loads the first page then appends the following pages', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      listHandler: (String? cursor) {
        switch (cursor) {
          case null:
            return DiagnosticsPage(
              items: <DiagnosticSummary>[
                sampleSummary(id: 'diag-1'),
                sampleSummary(id: 'diag-2'),
              ],
              nextCursor: 'cursor-1',
            );
          case 'cursor-1':
            return DiagnosticsPage(
              items: <DiagnosticSummary>[sampleSummary(id: 'diag-3')],
              nextCursor: 'cursor-2',
            );
          default:
            return DiagnosticsPage(
              items: <DiagnosticSummary>[sampleSummary(id: 'diag-4')],
            );
        }
      },
    );
    final ProviderContainer container = buildContainer(repository);

    final DiagnosticsHistoryState first = await container.read(
      diagnosticsHistoryProvider.future,
    );
    expect(first.items.map((DiagnosticSummary item) => item.id), <String>[
      'diag-1',
      'diag-2',
    ]);
    expect(first.nextCursor, 'cursor-1');

    await container.read(diagnosticsHistoryProvider.notifier).loadMore();

    DiagnosticsHistoryState state = container
        .read(diagnosticsHistoryProvider)
        .requireValue;
    expect(state.items.map((DiagnosticSummary item) => item.id), <String>[
      'diag-1',
      'diag-2',
      'diag-3',
    ]);
    expect(state.nextCursor, 'cursor-2');

    await container.read(diagnosticsHistoryProvider.notifier).loadMore();

    state = container.read(diagnosticsHistoryProvider).requireValue;
    expect(state.items.map((DiagnosticSummary item) => item.id), <String>[
      'diag-1',
      'diag-2',
      'diag-3',
      'diag-4',
    ]);
    expect(state.nextCursor, isNull);
    expect(repository.listCalls, 3);
  });

  test('loadMore does nothing when there is no next page', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[sampleSummary()],
    );
    final ProviderContainer container = buildContainer(repository);
    await container.read(diagnosticsHistoryProvider.future);

    await container.read(diagnosticsHistoryProvider.notifier).loadMore();

    expect(repository.listCalls, 1);
    expect(repository.requestedCursors, <String?>[null]);
    expect(
      container.read(diagnosticsHistoryProvider).requireValue.items,
      hasLength(1),
    );
  });

  test('loadMore ignores a call while a page is loading', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      listHandler: (String? cursor) {
        if (cursor == null) {
          return DiagnosticsPage(
            items: <DiagnosticSummary>[sampleSummary(id: 'diag-1')],
            nextCursor: 'cursor-1',
          );
        }
        return DiagnosticsPage(
          items: <DiagnosticSummary>[sampleSummary(id: 'diag-2')],
        );
      },
    );
    final ProviderContainer container = buildContainer(repository);
    await container.read(diagnosticsHistoryProvider.future);

    final DiagnosticsHistoryController controller = container.read(
      diagnosticsHistoryProvider.notifier,
    );
    final Future<void> first = controller.loadMore();
    final Future<void> second = controller.loadMore();
    await Future.wait(<Future<void>>[first, second]);

    expect(repository.listCalls, 2);
    expect(
      container.read(diagnosticsHistoryProvider).requireValue.items,
      hasLength(2),
    );
  });

  test('keeps the items when refreshing fails', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[sampleSummary()],
    );
    final ProviderContainer container = buildContainer(repository);
    await container.read(diagnosticsHistoryProvider.future);

    repository.listError = ApiException.network();
    await container.read(diagnosticsHistoryProvider.notifier).refresh();

    final AsyncValue<DiagnosticsHistoryState> state = container.read(
      diagnosticsHistoryProvider,
    );
    expect(state.hasError, isTrue);
  });

  test('removes an item optimistically after a successful deletion', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[
        sampleSummary(id: 'diag-1'),
        sampleSummary(id: 'diag-2'),
      ],
    );
    final ProviderContainer container = buildContainer(repository);
    await container.read(diagnosticsHistoryProvider.future);

    await container.read(diagnosticsHistoryProvider.notifier).delete('diag-1');

    final DiagnosticsHistoryState state = container
        .read(diagnosticsHistoryProvider)
        .requireValue;
    expect(state.items.map((DiagnosticSummary item) => item.id), <String>[
      'diag-2',
    ]);
    expect(repository.deletedIds, <String>['diag-1']);
  });

  test('restores an item and exposes the error when deletion fails', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[
        sampleSummary(id: 'diag-1'),
        sampleSummary(id: 'diag-2'),
      ],
    )..deleteError = ApiException.network();
    final ProviderContainer container = buildContainer(repository);
    await container.read(diagnosticsHistoryProvider.future);

    await expectLater(
      container.read(diagnosticsHistoryProvider.notifier).delete('diag-1'),
      throwsA(isA<ApiException>()),
    );

    final DiagnosticsHistoryState state = container
        .read(diagnosticsHistoryProvider)
        .requireValue;
    expect(state.items.map((DiagnosticSummary item) => item.id), <String>[
      'diag-1',
      'diag-2',
    ]);
    expect(state.hasMore, isFalse);
  });
}
