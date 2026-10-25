import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/diagnostic_summary.dart';
import 'diagnostics_repository.dart';

class DiagnosticsHistoryState {
  const DiagnosticsHistoryState({
    this.items = const <DiagnosticSummary>[],
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<DiagnosticSummary> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  DiagnosticsHistoryState copyWith({
    List<DiagnosticSummary>? items,
    Object? nextCursor = _unset,
    bool? loadingMore,
  }) {
    return DiagnosticsHistoryState(
      items: items ?? this.items,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as String?,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

const Object _unset = Object();

class DiagnosticsHistoryController
    extends AsyncNotifier<DiagnosticsHistoryState> {
  @override
  Future<DiagnosticsHistoryState> build() async {
    final DiagnosticsPage page = await ref
        .watch(diagnosticsRepositoryProvider)
        .list();
    return DiagnosticsHistoryState(
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final DiagnosticsHistoryState? current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData<DiagnosticsHistoryState>(
      current.copyWith(loadingMore: true),
    );
    try {
      final DiagnosticsPage page = await ref
          .read(diagnosticsRepositoryProvider)
          .list(cursor: current.nextCursor);
      if (!ref.mounted) {
        return;
      }
      final DiagnosticsHistoryState latest = state.value ?? current;
      state = AsyncData<DiagnosticsHistoryState>(
        latest.copyWith(
          items: <DiagnosticSummary>[...latest.items, ...page.items],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      final DiagnosticsHistoryState latest = state.value ?? current;
      state = AsyncData<DiagnosticsHistoryState>(
        latest.copyWith(loadingMore: false),
      );
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<DiagnosticsHistoryState>(() async {
      final DiagnosticsPage page = await ref
          .read(diagnosticsRepositoryProvider)
          .list();
      return DiagnosticsHistoryState(
        items: page.items,
        nextCursor: page.nextCursor,
      );
    });
  }

  Future<void> delete(String id) async {
    final DiagnosticsHistoryState? current = state.value;
    if (current == null) {
      await ref.read(diagnosticsRepositoryProvider).delete(id);
      return;
    }
    final int index = current.items.indexWhere(
      (DiagnosticSummary item) => item.id == id,
    );
    final DiagnosticsHistoryState optimistic = current.copyWith(
      items: current.items
          .where((DiagnosticSummary item) => item.id != id)
          .toList(),
    );
    state = AsyncData<DiagnosticsHistoryState>(optimistic);
    try {
      await ref.read(diagnosticsRepositoryProvider).delete(id);
    } catch (error) {
      if (ref.mounted) {
        final DiagnosticsHistoryState latest = state.value ?? optimistic;
        final List<DiagnosticSummary> restored = List<DiagnosticSummary>.of(
          latest.items,
        );
        if (index >= 0 &&
            index <= restored.length &&
            !restored.any((DiagnosticSummary item) => item.id == id)) {
          restored.insert(index, current.items[index]);
        }
        state = AsyncData<DiagnosticsHistoryState>(
          latest.copyWith(items: restored),
        );
      }
      rethrow;
    }
  }
}

final AsyncNotifierProvider<
  DiagnosticsHistoryController,
  DiagnosticsHistoryState
>
diagnosticsHistoryProvider =
    AsyncNotifierProvider<
      DiagnosticsHistoryController,
      DiagnosticsHistoryState
    >(
      DiagnosticsHistoryController.new,
      retry: (int retryCount, Object error) => null,
    );
