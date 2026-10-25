import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/severity.dart';

Map<String, dynamic> diagnosticJson({
  String status = 'done',
  String? error,
  Object? confidence = '0.92',
  String? severity = 'high',
  bool withRecommendation = true,
  bool withOnDevice = false,
}) {
  return <String, dynamic>{
    'id': 'diag-1',
    'status': status,
    'error': error,
    'confidence': confidence,
    'severity': severity,
    'crop_id': 3,
    'plot_id': 'plot-1',
    'crop_cycle_id': null,
    'source': 'server',
    'user_note': null,
    'location': null,
    'created_at': '2026-10-24T10:00:00Z',
    'updated_at': '2026-10-24T10:00:05Z',
    'completed_at': status == 'done' ? '2026-10-24T10:00:05Z' : null,
    'media': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'media-1',
        'kind': 'image',
        'mime_type': 'image/jpeg',
        'url': 'http://storage.local/media-1',
      },
    ],
    'predictions': <Map<String, dynamic>>[
      <String, dynamic>{
        'rank': 1,
        'confidence': 0.92,
        'label': <String, dynamic>{
          'id': 1,
          'code': 'MILDEW',
          'kind': 'disease',
          'name': 'Mildiou',
        },
      },
      <String, dynamic>{
        'rank': 2,
        'confidence': 0.05,
        'label': <String, dynamic>{
          'id': 2,
          'code': 'RUST',
          'kind': 'disease',
          'name': 'Rouille',
        },
      },
    ],
    'on_device_prediction': withOnDevice
        ? <String, dynamic>{
            'rank': 1,
            'confidence': 0.81,
            'label': <String, dynamic>{
              'id': 1,
              'code': 'MILDEW',
              'kind': 'disease',
              'name': 'Mildiou',
            },
          }
        : null,
    'recommendation': withRecommendation
        ? <String, dynamic>{
            'id': 'rec-1',
            'diagnostic_id': 'diag-1',
            'plot_id': 'plot-1',
            'crop_cycle_id': null,
            'source': 'rules',
            'language': 'fr',
            'title': 'Recommandation pour Mildiou',
            'body': 'Retirez les feuilles atteintes.',
            'steps': <Map<String, dynamic>>[
              <String, dynamic>{
                'category': 'cultural',
                'text': 'Aérez la parcelle.',
              },
              <String, dynamic>{
                'category': 'prevention',
                'text': 'Surveillez chaque semaine.',
              },
            ],
            'citations': null,
            'status': 'published',
            'validated_by': null,
            'created_at': '2026-10-24T10:00:06Z',
          }
        : null,
  };
}

void main() {
  test('parses every diagnostic status and terminal flags', () {
    expect(
      Diagnostic.fromJson(diagnosticJson(status: 'pending')).status,
      DiagnosticStatus.pending,
    );
    expect(
      Diagnostic.fromJson(diagnosticJson(status: 'processing')).status,
      DiagnosticStatus.processing,
    );
    expect(DiagnosticStatus.done.isTerminal, isTrue);
    expect(DiagnosticStatus.needsReview.isTerminal, isTrue);
    expect(DiagnosticStatus.failed.isTerminal, isTrue);
    expect(DiagnosticStatus.pending.isTerminal, isFalse);
    expect(DiagnosticStatus.processing.isTerminal, isFalse);
    expect(DiagnosticStatus.needsReview.apiValue, 'needs_review');
  });

  test('parses the detail, prediction, media and recommendation', () {
    final Diagnostic diagnostic = Diagnostic.fromJson(
      diagnosticJson(withOnDevice: true),
    );

    expect(diagnostic.id, 'diag-1');
    expect(diagnostic.status, DiagnosticStatus.done);
    expect(diagnostic.confidence, 0.92);
    expect(diagnostic.severity, Severity.high);
    expect(diagnostic.cropId, 3);
    expect(diagnostic.plotId, 'plot-1');
    expect(diagnostic.completedAt, DateTime.utc(2026, 10, 24, 10, 0, 5));
    expect(diagnostic.medias.single.id, 'media-1');
    expect(diagnostic.medias.single.url, 'http://storage.local/media-1');
    expect(diagnostic.predictions, hasLength(2));
    expect(diagnostic.predictions.first.label.name, 'Mildiou');
    expect(diagnostic.predictions.first.label.kind, 'disease');
    expect(diagnostic.onDevicePrediction?.confidence, 0.81);
    expect(diagnostic.recommendation?.id, 'rec-1');
    expect(diagnostic.recommendation?.isPublished, isTrue);
    expect(diagnostic.recommendation?.steps, hasLength(2));
    expect(diagnostic.recommendation?.steps.first.category, 'cultural');
    expect(diagnostic.recommendation?.steps.first.text, 'Aérez la parcelle.');
  });

  test('accepts a diagnostic without a recommendation', () {
    final Diagnostic diagnostic = Diagnostic.fromJson(
      diagnosticJson(withRecommendation: false),
    );

    expect(diagnostic.recommendation, isNull);
    expect(diagnostic.onDevicePrediction, isNull);
  });

  test('accepts a failed diagnostic with an error and no confidence', () {
    final Diagnostic diagnostic = Diagnostic.fromJson(
      diagnosticJson(
        status: 'failed',
        error: 'Analyse impossible.',
        confidence: null,
        severity: null,
        withRecommendation: false,
      ),
    );

    expect(diagnostic.status, DiagnosticStatus.failed);
    expect(diagnostic.error, 'Analyse impossible.');
    expect(diagnostic.confidence, isNull);
    expect(diagnostic.severity, isNull);
  });
}
