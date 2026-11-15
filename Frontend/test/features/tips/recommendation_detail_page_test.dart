import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/tips/domain/recommendation.dart';
import 'package:smartagri/features/tips/presentation/recommendation_detail_page.dart';

import '../app_test_utils.dart';
import 'fake_recommendations_repository.dart';

class RecordingFeedbackRepository extends DiagnosticsRepository {
  RecordingFeedbackRepository() : super(dio: Dio());

  int feedbackCalls = 0;
  bool? lastHelpful;
  bool? lastApplied;

  @override
  Future<void> sendFeedback(
    String recommendationId, {
    required bool helpful,
    bool? applied,
    String? comment,
  }) async {
    feedbackCalls++;
    lastHelpful = helpful;
    lastApplied = applied;
  }
}

GoRouter detailRouter(String recommendationId) {
  return GoRouter(
    initialLocation: '/tips/$recommendationId',
    routes: <RouteBase>[
      GoRoute(
        path: '/tips/:recommendationId',
        builder: (_, GoRouterState state) => RecommendationDetailPage(
          recommendationId: state.pathParameters['recommendationId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/diagnostic/:diagnosticId',
        builder: (_, GoRouterState state) => Scaffold(
          body: Text(
            'route diagnostic ${state.pathParameters['diagnosticId']}',
          ),
        ),
      ),
    ],
  );
}

Future<void> pumpDetail(
  WidgetTester tester, {
  required String id,
  FakeRecommendationsRepository? repository,
  DiagnosticsRepository? diagnosticsRepository,
  bool settle = true,
}) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    recommendationsRepository: repository,
    diagnosticsRepository: diagnosticsRepository,
  );
  await tester.pumpWidget(testRouterApp(container, detailRouter(id)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders the content, numbered steps and the disclaimer', (
    WidgetTester tester,
  ) async {
    final Recommendation recommendation = sampleRecommendation();
    await pumpDetail(
      tester,
      id: recommendation.id,
      repository: FakeRecommendationsRepository(
        items: <Recommendation>[recommendation],
        detail: recommendation,
      ),
    );

    expect(find.text('Traiter le mildiou'), findsOneWidget);
    expect(
      find.text('Retirez les feuilles atteintes et appliquez un fongicide.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recommendation_step_0')), findsOneWidget);
    expect(find.byKey(const Key('recommendation_step_1')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text('Consultez un technicien agricole avant tout traitement.'),
      findsOneWidget,
    );
  });

  testWidgets('opens the linked diagnostic', (WidgetTester tester) async {
    final Recommendation recommendation = sampleRecommendation();
    await pumpDetail(
      tester,
      id: recommendation.id,
      repository: FakeRecommendationsRepository(
        items: <Recommendation>[recommendation],
        detail: recommendation,
      ),
    );

    await tester.tap(find.byKey(const Key('recommendation_see_diagnostic')));
    await tester.pumpAndSettle();

    expect(find.text('route diagnostic diag-1'), findsOneWidget);
  });

  testWidgets('sends the feedback with the applied flag', (
    WidgetTester tester,
  ) async {
    final Recommendation recommendation = sampleRecommendation();
    final RecordingFeedbackRepository diagnostics =
        RecordingFeedbackRepository();
    await pumpDetail(
      tester,
      id: recommendation.id,
      repository: FakeRecommendationsRepository(
        items: <Recommendation>[recommendation],
        detail: recommendation,
      ),
      diagnosticsRepository: diagnostics,
    );

    await tester.ensureVisible(
      find.byKey(const Key('recommendation_feedback_applied')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recommendation_feedback_applied')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recommendation_feedback_yes')));
    await tester.pumpAndSettle();

    expect(diagnostics.feedbackCalls, 1);
    expect(diagnostics.lastHelpful, isTrue);
    expect(diagnostics.lastApplied, isTrue);
    expect(
      find.byKey(const Key('recommendation_feedback_thanks')),
      findsOneWidget,
    );
  });

  testWidgets('shows the offline message and retries', (
    WidgetTester tester,
  ) async {
    final Recommendation recommendation = sampleRecommendation();
    final FakeRecommendationsRepository repository =
        FakeRecommendationsRepository(
            items: <Recommendation>[recommendation],
            detail: recommendation,
          )
          ..detailError = const ApiException(
            code: ApiException.networkErrorCode,
            message: 'offline',
          );
    await pumpDetail(tester, id: recommendation.id, repository: repository);

    expect(
      find.text('Les conseils nécessitent une connexion Internet.'),
      findsOneWidget,
    );

    repository.detailError = null;
    await tester.tap(find.byKey(const Key('recommendation_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Traiter le mildiou'), findsOneWidget);
  });

  testWidgets('shows skeletons while loading', (WidgetTester tester) async {
    final Recommendation recommendation = sampleRecommendation();
    final FakeRecommendationsRepository repository =
        FakeRecommendationsRepository(
          items: <Recommendation>[recommendation],
          detail: recommendation,
        )..detailCompleter = Completer<Recommendation>();
    await pumpDetail(
      tester,
      id: recommendation.id,
      repository: repository,
      settle: false,
    );

    expect(
      find.byKey(const Key('recommendation_detail_skeleton_0')),
      findsOneWidget,
    );

    repository.detailCompleter!.complete(recommendation);
    await tester.pumpAndSettle();
    expect(find.text('Traiter le mildiou'), findsOneWidget);
  });
}
