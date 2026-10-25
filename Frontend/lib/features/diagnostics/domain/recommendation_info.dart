class RecommendationStep {
  const RecommendationStep({required this.category, required this.text});

  final String category;
  final String text;

  factory RecommendationStep.fromJson(Object? value) {
    if (value is String) {
      return RecommendationStep(category: '', text: value);
    }
    if (value is Map) {
      final Map<String, dynamic> json = Map<String, dynamic>.from(value);
      return RecommendationStep(
        category: json['category'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
    }
    return const RecommendationStep(category: '', text: '');
  }
}

class RecommendationInfo {
  const RecommendationInfo({
    required this.id,
    required this.title,
    required this.body,
    required this.steps,
    required this.status,
  });

  final String id;
  final String title;
  final String body;
  final List<RecommendationStep> steps;
  final String status;

  bool get isPublished => status == 'published';

  factory RecommendationInfo.fromJson(Map<String, dynamic> json) {
    final Object? rawSteps = json['steps'];
    return RecommendationInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      steps: rawSteps is List
          ? rawSteps.map(RecommendationStep.fromJson).toList()
          : <RecommendationStep>[],
      status: json['status'] as String? ?? '',
    );
  }
}
