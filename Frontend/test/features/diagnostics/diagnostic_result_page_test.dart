import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/diagnostics/data/diagnostic_watcher.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_media.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/prediction.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_result_page.dart';

import 'diagnostic_test_utils.dart';

class FixedWatchController extends DiagnosticWatchController {
  FixedWatchController(super.diagnosticId, this.initial);

  final DiagnosticWatchState initial;
  int resumeCalls = 0;

  @override
  DiagnosticWatchState build() => initial;

  @override
  Future<void> resume() async {
    resumeCalls++;
    state = AsyncData<DiagnosticWatchState>(initial);
  }
}

class ErrorWatchController extends DiagnosticWatchController {
  ErrorWatchController(super.diagnosticId, this.error);

  final Object error;

  @override
  DiagnosticWatchState build() => throw error;
}

class FakeDiagnosticsRepository extends DiagnosticsRepository {
  FakeDiagnosticsRepository() : super(dio: Dio());

  int retryCalls = 0;
  int deleteCalls = 0;
  int feedbackCalls = 0;
  String? lastDeletedId;
  String? lastRecommendationId;
  bool? lastHelpful;

  @override
  Future<Diagnostic> retry(String id) async {
    retryCalls++;
    return sampleDiagnostic(status: DiagnosticStatus.pending);
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    lastDeletedId = id;
  }

  @override
  Future<void> sendFeedback(
    String recommendationId, {
    required bool helpful,
    bool? applied,
    String? comment,
  }) async {
    feedbackCalls++;
    lastRecommendationId = recommendationId;
    lastHelpful = helpful;
  }
}

GoRouter buildResultRouter() {
  return GoRouter(
    initialLocation: '/diagnostic/diag-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/diagnostic/:diagnosticId',
        builder: (_, GoRouterState state) => DiagnosticResultPage(
          diagnosticId: state.pathParameters['diagnosticId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('route accueil')),
      ),
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const Scaffold(body: Text('route nouveau')),
      ),
    ],
  );
}

Future<(ProviderContainer, FakeDiagnosticsRepository)> pumpResult(
  WidgetTester tester, {
  required DiagnosticWatchState state,
  bool demo = true,
  FakeDiagnosticsRepository? repository,
  DiagnosticWatchController? controller,
  Object? error,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final FakeDiagnosticsRepository fake =
      repository ?? FakeDiagnosticsRepository();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      diagnosticsRepositoryProvider.overrideWithValue(fake),
      diagnosticDemoBannerProvider.overrideWithValue(demo),
      diagnosticWatchProvider('diag-1').overrideWith(
        () =>
            controller ??
            (error != null
                ? ErrorWatchController('diag-1', error)
                : FixedWatchController('diag-1', state)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: buildResultRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, fake);
}

void main() {
  testWidgets('renders a completed diagnosis with advice and feedback', (
    WidgetTester tester,
  ) async {
    final (_, FakeDiagnosticsRepository repository) = await pumpResult(
      tester,
      state: DiagnosticWatchState(
        diagnostic: sampleDiagnostic(recommendation: sampleRecommendation()),
      ),
    );

    expect(find.byKey(const Key('diagnostic_main_label')), findsOneWidget);
    expect(find.text('Mildiou'), findsOneWidget);
    expect(find.text('Confiance 92 %'), findsOneWidget);
    expect(find.byKey(const Key('status_chip_danger')), findsOneWidget);
    expect(find.text('Élevée'), findsOneWidget);
    expect(find.text('Autres possibilités'), findsOneWidget);
    expect(find.text('Rouille'), findsOneWidget);
    expect(find.text('Recommandation pour Mildiou'), findsOneWidget);
    expect(find.text('Retirez les feuilles atteintes.'), findsOneWidget);
    expect(find.text('Pratiques culturales'), findsOneWidget);
    expect(find.text('Aérez la parcelle.'), findsOneWidget);
    expect(find.text('Prévention'), findsOneWidget);
    expect(find.text('Surveillez chaque semaine.'), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_technician')), findsOneWidget);

    await tester.tap(find.byKey(const Key('diagnostic_feedback_yes')));
    await tester.pumpAndSettle();

    expect(repository.feedbackCalls, 1);
    expect(repository.lastRecommendationId, 'rec-1');
    expect(repository.lastHelpful, isTrue);
    expect(find.byKey(const Key('diagnostic_feedback_thanks')), findsOneWidget);
  });

  testWidgets('uses the healthy chip for a healthy prediction', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      state: DiagnosticWatchState(
        diagnostic: sampleDiagnostic(
          severity: null,
          confidence: 0.99,
          predictions: <Prediction>[
            samplePrediction(
              confidence: 0.99,
              label: sampleLabel(kind: 'healthy', name: 'Feuille saine'),
            ),
          ],
          recommendation: sampleRecommendation(),
        ),
      ),
    );

    expect(find.text('Feuille saine'), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_healthy_chip')), findsOneWidget);
    expect(find.text('Culture saine'), findsOneWidget);
    expect(find.byKey(const Key('status_chip_success')), findsOneWidget);
  });

  testWidgets('renders the processing state and the sent media', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      state: DiagnosticWatchState(
        diagnostic: sampleDiagnostic(
          status: DiagnosticStatus.processing,
          confidence: null,
          severity: null,
          predictions: const <Prediction>[],
          medias: const <DiagnosticMedia>[
            DiagnosticMedia(id: 'media-1', kind: 'image'),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('diagnostic_processing')), findsOneWidget);
    expect(
      find.byKey(const Key('diagnostic_result_media_media-1')),
      findsOneWidget,
    );
    expect(find.text('Cela prend quelques secondes'), findsOneWidget);
  });

  testWidgets('renders the expert review state', (WidgetTester tester) async {
    await pumpResult(
      tester,
      state: DiagnosticWatchState(
        diagnostic: sampleDiagnostic(
          status: DiagnosticStatus.needsReview,
          confidence: null,
          recommendation: null,
          predictions: <Prediction>[samplePrediction()],
        ),
      ),
    );

    expect(find.byKey(const Key('diagnostic_expert_review')), findsOneWidget);
    expect(find.text('Prédictions provisoires'), findsOneWidget);
    expect(find.text('Mildiou'), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_feedback_yes')), findsNothing);
  });

  testWidgets('retries a failed diagnosis', (WidgetTester tester) async {
    final (_, FakeDiagnosticsRepository repository) = await pumpResult(
      tester,
      state: DiagnosticWatchState(
        diagnostic: sampleDiagnostic(
          status: DiagnosticStatus.failed,
          error: 'Analyse impossible.',
          confidence: null,
          severity: null,
          predictions: const <Prediction>[],
        ),
      ),
    );

    expect(find.byKey(const Key('diagnostic_failed')), findsOneWidget);
    expect(find.text('Analyse impossible.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('diagnostic_retry')));
    await tester.pumpAndSettle();

    expect(repository.retryCalls, 1);
  });

  testWidgets('refreshes after a watch timeout', (WidgetTester tester) async {
    final FixedWatchController controller = FixedWatchController(
      'diag-1',
      DiagnosticWatchState(
        diagnostic: sampleDiagnostic(status: DiagnosticStatus.processing),
        timedOut: true,
      ),
    );
    await pumpResult(tester, state: controller.initial, controller: controller);

    expect(find.byKey(const Key('diagnostic_timeout')), findsOneWidget);

    await tester.tap(find.byKey(const Key('diagnostic_refresh')));
    await tester.pumpAndSettle();

    expect(controller.resumeCalls, 1);
  });

  testWidgets('shows the watch error and a retry action', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      state: const DiagnosticWatchState(),
      error: Exception('panne'),
    );

    expect(find.byKey(const Key('diagnostic_failed')), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_retry')), findsOneWidget);
  });

  testWidgets('shows the demo banner when enabled', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      state: DiagnosticWatchState(diagnostic: sampleDiagnostic()),
      demo: true,
    );
    expect(find.byKey(const Key('diagnostic_demo_banner')), findsOneWidget);
  });

  testWidgets('hides the demo banner when disabled', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      state: DiagnosticWatchState(diagnostic: sampleDiagnostic()),
      demo: false,
    );
    expect(find.byKey(const Key('diagnostic_demo_banner')), findsNothing);
  });

  testWidgets('deletes the diagnosis after confirmation', (
    WidgetTester tester,
  ) async {
    final (_, FakeDiagnosticsRepository repository) = await pumpResult(
      tester,
      state: DiagnosticWatchState(diagnostic: sampleDiagnostic()),
    );

    await tester.tap(find.byKey(const Key('diagnostic_result_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer ce diagnostic'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le diagnostic ?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('diagnostic_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.lastDeletedId, 'diag-1');
    expect(find.text('route accueil'), findsOneWidget);
  });

  testWidgets('does not show an unpublished recommendation', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      state: DiagnosticWatchState(
        diagnostic: sampleDiagnostic(
          recommendation: sampleRecommendation(status: 'draft'),
        ),
      ),
    );

    expect(find.text('Recommandation pour Mildiou'), findsNothing);
    expect(find.text('Conseils'), findsNothing);
  });
}
