import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';
import 'package:smartagri/features/diagnostics/domain/severity.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_row.dart';

import '../app_test_utils.dart';
import 'fake_diagnostics_repository.dart';

Future<ProviderContainer> pumpRow(
  WidgetTester tester,
  DiagnosticSummary summary,
) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
  );
  await tester.pumpWidget(
    testApp(
      container,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DiagnosticRow(summary: summary),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows every status label and colour variant', (
    WidgetTester tester,
  ) async {
    const Map<DiagnosticStatus, String> labels = <DiagnosticStatus, String>{
      DiagnosticStatus.done: 'Terminé',
      DiagnosticStatus.needsReview: 'À vérifier',
      DiagnosticStatus.failed: 'Échec',
      DiagnosticStatus.pending: 'En cours',
      DiagnosticStatus.processing: 'En cours',
    };
    for (final MapEntry<DiagnosticStatus, String> entry in labels.entries) {
      await pumpRow(tester, sampleSummary(status: entry.key));
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('shows every severity label', (WidgetTester tester) async {
    const Map<Severity, String> labels = <Severity, String>{
      Severity.low: 'Faible',
      Severity.medium: 'Moyenne',
      Severity.high: 'Élevée',
    };
    for (final MapEntry<Severity, String> entry in labels.entries) {
      await pumpRow(tester, sampleSummary(severity: entry.key));
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('hides the severity chip when the severity is missing', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, sampleSummary(severity: null));

    expect(find.text('Faible'), findsNothing);
    expect(find.text('Moyenne'), findsNothing);
    expect(find.text('Élevée'), findsNothing);
  });

  testWidgets('shows the leaf icon when there is no thumbnail', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, sampleSummary());

    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the provided label and the French date', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, sampleSummary(labelName: 'Mildiou'));

    expect(find.text('Mildiou'), findsOneWidget);
    expect(find.text('24 oct. 2026, 14:05'), findsOneWidget);
  });

  testWidgets('falls back to the in-progress title without a label', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, sampleSummary(labelName: null));

    expect(find.text('Analyse en cours…'), findsOneWidget);
  });
}
