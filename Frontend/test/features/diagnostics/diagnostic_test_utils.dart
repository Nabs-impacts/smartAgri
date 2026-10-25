import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_media.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/prediction.dart';
import 'package:smartagri/features/diagnostics/domain/recommendation_info.dart';
import 'package:smartagri/features/diagnostics/domain/severity.dart';

DiagnosticLabel sampleLabel({
  int id = 1,
  String code = 'MILDEW',
  String kind = 'disease',
  String name = 'Mildiou',
}) {
  return DiagnosticLabel(id: id, code: code, kind: kind, name: name);
}

Prediction samplePrediction({
  int rank = 1,
  double confidence = 0.92,
  DiagnosticLabel? label,
}) {
  return Prediction(
    rank: rank,
    confidence: confidence,
    label: label ?? sampleLabel(),
  );
}

RecommendationInfo sampleRecommendation({
  String status = 'published',
  List<RecommendationStep>? steps,
}) {
  return RecommendationInfo(
    id: 'rec-1',
    title: 'Recommandation pour Mildiou',
    body: 'Retirez les feuilles atteintes.',
    steps:
        steps ??
        const <RecommendationStep>[
          RecommendationStep(category: 'cultural', text: 'Aérez la parcelle.'),
          RecommendationStep(
            category: 'prevention',
            text: 'Surveillez chaque semaine.',
          ),
        ],
    status: status,
  );
}

Diagnostic sampleDiagnostic({
  String id = 'diag-1',
  DiagnosticStatus status = DiagnosticStatus.done,
  double? confidence = 0.92,
  Severity? severity = Severity.high,
  String? error,
  List<DiagnosticMedia> medias = const <DiagnosticMedia>[],
  List<Prediction>? predictions,
  RecommendationInfo? recommendation,
}) {
  return Diagnostic(
    id: id,
    status: status,
    createdAt: DateTime.utc(2026, 10, 24, 10),
    completedAt: status.isTerminal
        ? DateTime.utc(2026, 10, 24, 10, 0, 5)
        : null,
    confidence: confidence,
    severity: severity,
    error: error,
    medias: medias,
    predictions:
        predictions ??
        (status == DiagnosticStatus.done
            ? <Prediction>[
                samplePrediction(),
                samplePrediction(
                  rank: 2,
                  confidence: 0.05,
                  label: sampleLabel(id: 2, code: 'RUST', name: 'Rouille'),
                ),
              ]
            : const <Prediction>[]),
    recommendation: recommendation,
  );
}
