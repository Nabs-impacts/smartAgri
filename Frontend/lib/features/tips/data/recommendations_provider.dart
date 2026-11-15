import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recommendation.dart';
import 'recommendations_repository.dart';

class RecommendationsState {
  const RecommendationsState({
    this.items = const <Recommendation>[],
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<Recommendation> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  RecommendationsState copyWith({
    List<Recommendation>? items,
    Object? nextCursor = _unset,
    bool? loadingMore,
  }) {
    return RecommendationsState(
      items: items ?? this.items,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as String?,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

const Object _unset = Object();

class RecommendationsController extends AsyncNotifier<RecommendationsState> {
  @override
  Future<RecommendationsState> build() async {
    final RecommendationsPage page = await ref
        .watch(recommendationsRepositoryProvider)
        .list();
    return RecommendationsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final RecommendationsState? current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData<RecommendationsState>(
      current.copyWith(loadingMore: true),
    );
    try {
      final RecommendationsPage page = await ref
          .read(recommendationsRepositoryProvider)
          .list(cursor: current.nextCursor);
      if (!ref.mounted) {
        return;
      }
      final RecommendationsState latest = state.value ?? current;
      state = AsyncData<RecommendationsState>(
        latest.copyWith(
          items: <Recommendation>[...latest.items, ...page.items],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      final RecommendationsState latest = state.value ?? current;
      state = AsyncData<RecommendationsState>(
        latest.copyWith(loadingMore: false),
      );
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<RecommendationsState>(() async {
      final RecommendationsPage page = await ref
          .read(recommendationsRepositoryProvider)
          .list();
      return RecommendationsState(
        items: page.items,
        nextCursor: page.nextCursor,
      );
    });
  }
}

final AsyncNotifierProvider<RecommendationsController, RecommendationsState>
recommendationsProvider =
    AsyncNotifierProvider<RecommendationsController, RecommendationsState>(
      RecommendationsController.new,
      retry: (int retryCount, Object error) => null,
    );

final recommendationProvider = FutureProvider.family<Recommendation, String>(
  (Ref ref, String id) => ref.watch(recommendationsRepositoryProvider).get(id),
  retry: (int retryCount, Object error) => null,
);
