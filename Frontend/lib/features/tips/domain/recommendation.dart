import '../../diagnostics/domain/recommendation_info.dart';

class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.body,
    required this.steps,
    required this.status,
    required this.language,
    required this.createdAt,
    this.diagnosticId,
    this.plotId,
    this.cropCycleId,
  });

  final String id;
  final String? diagnosticId;
  final String? plotId;
  final String? cropCycleId;
  final String title;
  final String body;
  final List<RecommendationStep> steps;
  final String status;
  final String language;
  final DateTime createdAt;

  bool get isPublished => status == 'published';

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final Object? rawSteps = json['steps'];
    return Recommendation(
      id: json['id'] as String? ?? '',
      diagnosticId: json['diagnostic_id'] as String?,
      plotId: json['plot_id'] as String?,
      cropCycleId: json['crop_cycle_id'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      steps: rawSteps is List
          ? rawSteps.map(RecommendationStep.fromJson).toList()
          : <RecommendationStep>[],
      status: json['status'] as String? ?? '',
      language: json['language'] as String? ?? '',
      createdAt: _date(json['created_at']),
    );
  }
}

class RecommendationsPage {
  const RecommendationsPage({required this.items, this.nextCursor});

  final List<Recommendation> items;
  final String? nextCursor;

  factory RecommendationsPage.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    final List<Recommendation> items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (Map item) =>
                    Recommendation.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((Recommendation item) => item.isPublished)
              .toList()
        : <Recommendation>[];
    return RecommendationsPage(
      items: items,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

DateTime _date(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
