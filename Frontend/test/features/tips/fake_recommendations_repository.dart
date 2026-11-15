import 'dart:async';

import 'package:dio/dio.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/domain/recommendation_info.dart';
import 'package:smartagri/features/tips/data/recommendations_repository.dart';
import 'package:smartagri/features/tips/domain/recommendation.dart';

Recommendation sampleRecommendation({
  String id = 'rec-1',
  String title = 'Traiter le mildiou',
  String body = 'Retirez les feuilles atteintes et appliquez un fongicide.',
  String? diagnosticId = 'diag-1',
  String status = 'published',
  DateTime? createdAt,
  List<RecommendationStep> steps = const <RecommendationStep>[
    RecommendationStep(category: 'treatment', text: 'Retirer les feuilles'),
    RecommendationStep(category: 'treatment', text: 'Appliquer le traitement'),
  ],
}) {
  return Recommendation(
    id: id,
    diagnosticId: diagnosticId,
    plotId: 'plot-1',
    cropCycleId: 'cycle-1',
    title: title,
    body: body,
    steps: steps,
    status: status,
    language: 'fr',
    createdAt: createdAt ?? DateTime(2026, 11, 10),
  );
}

class FakeRecommendationsRepository extends RecommendationsRepository {
  FakeRecommendationsRepository({
    List<Recommendation>? items,
    this.nextCursor,
    List<Recommendation>? nextItems,
    this.detail,
  }) : items = items ?? <Recommendation>[],
       nextItems = nextItems ?? <Recommendation>[],
       super(dio: Dio());

  List<Recommendation> items;
  String? nextCursor;
  List<Recommendation> nextItems;
  Recommendation? detail;
  ApiException? error;
  ApiException? detailError;
  Completer<RecommendationsPage>? completer;
  Completer<Recommendation>? detailCompleter;

  int listCalls = 0;
  int detailCalls = 0;
  final List<String?> requestedCursors = <String?>[];

  @override
  Future<RecommendationsPage> list({
    String? cursor,
    int limit = 20,
    String? plotId,
    String? cropCycleId,
  }) async {
    listCalls++;
    requestedCursors.add(cursor);
    if (completer != null) {
      return completer!.future;
    }
    if (error != null) {
      throw error!;
    }
    if (cursor == null) {
      return RecommendationsPage(items: items, nextCursor: nextCursor);
    }
    return RecommendationsPage(items: nextItems);
  }

  @override
  Future<Recommendation> get(String id) async {
    detailCalls++;
    if (detailCompleter != null) {
      return detailCompleter!.future;
    }
    if (detailError != null) {
      throw detailError!;
    }
    if (detail != null && detail!.id == id) {
      return detail!;
    }
    return items.firstWhere((Recommendation item) => item.id == id);
  }
}
