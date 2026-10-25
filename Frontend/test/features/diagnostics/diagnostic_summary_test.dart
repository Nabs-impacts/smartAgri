import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';
import 'package:smartagri/features/diagnostics/domain/severity.dart';

Map<String, dynamic> summaryJson({
  String status = 'done',
  String? severity = 'high',
  Object? confidence = '0.92',
  Object? labelName,
  Object? thumbnailUrl,
}) {
  return <String, dynamic>{
    'id': 'diag-1',
    'status': status,
    'error': null,
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
    'completed_at': '2026-10-24T10:00:05Z',
    'label_name': ?labelName,
    'thumbnail_url': ?thumbnailUrl,
  };
}

void main() {
  test('parses the list schema without inventing a label or thumbnail', () {
    final DiagnosticSummary summary = DiagnosticSummary.fromJson(summaryJson());

    expect(summary.id, 'diag-1');
    expect(summary.status, DiagnosticStatus.done);
    expect(summary.severity, Severity.high);
    expect(summary.confidence, 0.92);
    expect(summary.plotId, 'plot-1');
    expect(summary.createdAt, DateTime.utc(2026, 10, 24, 10));
    expect(summary.labelName, isNull);
    expect(summary.thumbnailUrl, isNull);
  });

  test('keeps the provided label and thumbnail', () {
    final DiagnosticSummary summary = DiagnosticSummary.fromJson(
      summaryJson(
        labelName: 'Mildiou',
        thumbnailUrl: 'http://storage.local/media-1',
      ),
    );

    expect(summary.labelName, 'Mildiou');
    expect(summary.thumbnailUrl, 'http://storage.local/media-1');
  });

  test('reads the first prediction label and media when provided', () {
    final Map<String, dynamic> json = summaryJson()
      ..['predictions'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'rank': 1,
          'confidence': 0.9,
          'label': <String, dynamic>{'name': 'Rouille'},
        },
      ]
      ..['media'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'media-1',
          'kind': 'image',
          'url': 'http://storage.local/media-1',
        },
      ];

    final DiagnosticSummary summary = DiagnosticSummary.fromJson(json);

    expect(summary.labelName, 'Rouille');
    expect(summary.thumbnailUrl, 'http://storage.local/media-1');
  });

  test('parses a page with items and a next cursor', () {
    final DiagnosticsPage page = DiagnosticsPage.fromJson(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        summaryJson(),
        summaryJson(status: 'failed'),
      ],
      'next_cursor': 'cursor-2',
    });

    expect(page.items, hasLength(2));
    expect(page.items.last.status, DiagnosticStatus.failed);
    expect(page.nextCursor, 'cursor-2');
  });

  test('falls back to a pending status and epoch date', () {
    final DiagnosticSummary summary = DiagnosticSummary.fromJson(
      <String, dynamic>{'id': 'diag-1', 'status': 'unknown'},
    );

    expect(summary.status, DiagnosticStatus.pending);
    expect(summary.severity, isNull);
    expect(summary.confidence, isNull);
    expect(summary.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
  });
}
