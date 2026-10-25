import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_history_provider.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostics_history_page.dart';

import '../app_test_utils.dart';
import 'fake_diagnostics_repository.dart';

GoRouter buildHistoryRouter() {
  return GoRouter(
    initialLocation: '/diagnostics',
    routes: <RouteBase>[
      GoRoute(
        path: '/diagnostics',
        builder: (_, _) => const DiagnosticsHistoryPage(),
      ),
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const Scaffold(body: Text('route nouveau')),
      ),
      GoRoute(
        path: '/diagnostic/:diagnosticId',
        builder: (_, GoRouterState state) => Scaffold(
          body: Text('route résultat ${state.pathParameters['diagnosticId']}'),
        ),
      ),
    ],
  );
}

Future<(ProviderContainer, FakeDiagnosticsRepository)> pumpHistory(
  WidgetTester tester,
  FakeDiagnosticsRepository repository,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    diagnosticsRepository: repository,
  );
  await tester.pumpWidget(testRouterApp(container, buildHistoryRouter()));
  await tester.pumpAndSettle();
  return (container, repository);
}

void main() {
  testWidgets('shows the history title and the diagnostic rows', (
    WidgetTester tester,
  ) async {
    await pumpHistory(
      tester,
      FakeDiagnosticsRepository(
        items: <DiagnosticSummary>[
          sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
          sampleSummary(id: 'diag-2', labelName: 'Rouille'),
        ],
      ),
    );

    expect(find.text('Mes diagnostics'), findsOneWidget);
    expect(find.byKey(const Key('diagnostic_row_diag-1')), findsOneWidget);
    expect(find.text('Mildiou'), findsOneWidget);
    expect(find.text('Rouille'), findsOneWidget);
  });

  testWidgets('opens the result page when a row is tapped', (
    WidgetTester tester,
  ) async {
    await pumpHistory(
      tester,
      FakeDiagnosticsRepository(
        items: <DiagnosticSummary>[sampleSummary(id: 'diag-1')],
      ),
    );

    await tester.tap(find.byKey(const Key('diagnostic_row_diag-1')));
    await tester.pumpAndSettle();

    expect(find.text('route résultat diag-1'), findsOneWidget);
  });

  testWidgets('loads the next page near the end of the list', (
    WidgetTester tester,
  ) async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      listHandler: (String? cursor) {
        if (cursor == null) {
          return DiagnosticsPage(
            items: <DiagnosticSummary>[
              for (int index = 0; index < 20; index++)
                sampleSummary(id: 'diag-$index', labelName: 'Analyse $index'),
            ],
            nextCursor: 'cursor-1',
          );
        }
        return DiagnosticsPage(
          items: <DiagnosticSummary>[
            sampleSummary(id: 'diag-old', labelName: 'Ancien diagnostic'),
          ],
        );
      },
    );
    final (ProviderContainer container, _) = await pumpHistory(
      tester,
      repository,
    );

    await tester.drag(
      find.byKey(const Key('diagnostics_history_scroll')),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedCursors, contains('cursor-1'));
    expect(
      container.read(diagnosticsHistoryProvider).requireValue.items,
      hasLength(21),
    );
  });

  testWidgets('shows the empty state and opens the new diagnostic page', (
    WidgetTester tester,
  ) async {
    await pumpHistory(tester, FakeDiagnosticsRepository());

    expect(find.text("Aucun diagnostic pour l'instant"), findsOneWidget);

    await tester.tap(find.byKey(const Key('diagnostics_history_new')));
    await tester.pumpAndSettle();

    expect(find.text('route nouveau'), findsOneWidget);
  });

  testWidgets('shows the error state and retries', (WidgetTester tester) async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository()
      ..listError = ApiException.network();
    await pumpHistory(tester, repository);

    expect(find.byKey(const Key('diagnostics_history_retry')), findsOneWidget);

    repository.listError = null;
    repository.items = <DiagnosticSummary>[
      sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
    ];
    await tester.tap(find.byKey(const Key('diagnostics_history_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Mildiou'), findsOneWidget);
  });

  testWidgets('deletes a diagnostic after confirmation', (
    WidgetTester tester,
  ) async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[
        sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
        sampleSummary(id: 'diag-2', labelName: 'Rouille'),
      ],
    );
    final (_, FakeDiagnosticsRepository fake) = await pumpHistory(
      tester,
      repository,
    );

    await tester.tap(find.byKey(const Key('diagnostic_row_menu_diag-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnostic_row_delete_diag-1')));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le diagnostic ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('diagnostics_delete_confirm')));
    await tester.pumpAndSettle();

    expect(fake.deletedIds, <String>['diag-1']);
    expect(find.byKey(const Key('diagnostic_row_diag-1')), findsNothing);
    expect(find.byKey(const Key('diagnostic_row_diag-2')), findsOneWidget);
  });

  testWidgets('restores the row and shows the error when deletion fails', (
    WidgetTester tester,
  ) async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[
        sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
      ],
    )..deleteError = ApiException.network();
    await pumpHistory(tester, repository);

    await tester.tap(find.byKey(const Key('diagnostic_row_menu_diag-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnostic_row_delete_diag-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnostics_delete_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostic_row_diag-1')), findsOneWidget);
    expect(
      find.text(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet.',
      ),
      findsOneWidget,
    );
  });
}
