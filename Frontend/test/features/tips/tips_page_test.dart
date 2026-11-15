import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/tips/domain/recommendation.dart';
import 'package:smartagri/features/tips/presentation/recommendation_detail_page.dart';
import 'package:smartagri/features/tips/presentation/tips_page.dart';

import '../app_test_utils.dart';
import 'fake_recommendations_repository.dart';

GoRouter tipsRouter() {
  return GoRouter(
    initialLocation: '/tips',
    routes: <RouteBase>[
      GoRoute(path: '/tips', builder: (_, _) => const TipsPage()),
      GoRoute(
        path: '/tips/:recommendationId',
        builder: (_, GoRouterState state) => RecommendationDetailPage(
          recommendationId: state.pathParameters['recommendationId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const Scaffold(body: Text('route diagnostic new')),
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

Future<FakeRecommendationsRepository> pumpTips(
  WidgetTester tester, {
  FakeRecommendationsRepository? repository,
  bool settle = true,
}) async {
  final FakeRecommendationsRepository repo =
      repository ?? FakeRecommendationsRepository();
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    recommendationsRepository: repo,
  );
  await tester.pumpWidget(testRouterApp(container, tipsRouter()));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return repo;
}

void main() {
  testWidgets('shows the assistant teaser and the recommendations', (
    WidgetTester tester,
  ) async {
    await pumpTips(
      tester,
      repository: FakeRecommendationsRepository(
        items: <Recommendation>[
          sampleRecommendation(id: 'rec-1', title: 'Traiter le mildiou'),
          sampleRecommendation(
            id: 'rec-2',
            title: 'Arroser le matin',
            body: 'Arrosez tôt pour limiter l’évaporation.',
          ),
        ],
      ),
    );

    expect(find.text('Conseiller IA GonaTa'), findsOneWidget);
    expect(find.text('Bientôt'), findsOneWidget);
    expect(
      find.text('Bientôt, posez vos questions agricoles à un assistant.'),
      findsOneWidget,
    );
    expect(find.text('Vos recommandations'), findsOneWidget);
    expect(find.text('Traiter le mildiou'), findsOneWidget);
    expect(find.text('Arroser le matin'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tips_row_rec-1')));
    await tester.pumpAndSettle();
    expect(find.byType(RecommendationDetailPage), findsOneWidget);
  });

  testWidgets('shows the empty state and opens the scanner', (
    WidgetTester tester,
  ) async {
    await pumpTips(tester);

    expect(
      find.text(
        'Aucun conseil pour le moment. Analysez une plante pour recevoir des recommandations.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tips_analyze')));
    await tester.pumpAndSettle();
    expect(find.text('route diagnostic new'), findsOneWidget);
  });

  testWidgets('shows the offline message and retries', (
    WidgetTester tester,
  ) async {
    final FakeRecommendationsRepository repo =
        FakeRecommendationsRepository(
            items: <Recommendation>[sampleRecommendation()],
          )
          ..error = const ApiException(
            code: ApiException.networkErrorCode,
            message: 'offline',
          );
    await pumpTips(tester, repository: repo);

    expect(
      find.text('Les conseils nécessitent une connexion Internet.'),
      findsOneWidget,
    );

    repo.error = null;
    await tester.tap(find.byKey(const Key('tips_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Traiter le mildiou'), findsOneWidget);
    expect(repo.listCalls, 2);
  });

  testWidgets('shows skeletons while loading', (WidgetTester tester) async {
    final FakeRecommendationsRepository repo = FakeRecommendationsRepository()
      ..completer = Completer<RecommendationsPage>();
    await pumpTips(tester, repository: repo, settle: false);

    expect(find.byKey(const Key('tips_skeleton_0')), findsOneWidget);

    repo.completer!.complete(
      RecommendationsPage(items: <Recommendation>[sampleRecommendation()]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Traiter le mildiou'), findsOneWidget);
  });

  testWidgets('loads more recommendations with the cursor', (
    WidgetTester tester,
  ) async {
    final FakeRecommendationsRepository repo = FakeRecommendationsRepository(
      items: <Recommendation>[sampleRecommendation(id: 'rec-1')],
      nextCursor: 'cursor-1',
      nextItems: <Recommendation>[
        sampleRecommendation(id: 'rec-2', title: 'Deuxième conseil'),
      ],
    );
    await pumpTips(tester, repository: repo);

    expect(find.byKey(const Key('tips_load_more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tips_load_more')));
    await tester.pumpAndSettle();

    expect(find.text('Deuxième conseil'), findsOneWidget);
    expect(repo.requestedCursors, <String?>[null, 'cursor-1']);
  });

  testWidgets('pull to refresh reloads the list', (WidgetTester tester) async {
    final FakeRecommendationsRepository repo = FakeRecommendationsRepository(
      items: <Recommendation>[sampleRecommendation()],
    );
    await pumpTips(tester, repository: repo);

    await tester.fling(
      find.byKey(const Key('tips_scroll')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repo.listCalls, greaterThanOrEqualTo(2));
  });
}
