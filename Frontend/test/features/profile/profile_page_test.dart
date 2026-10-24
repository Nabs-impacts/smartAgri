import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_progress_bar.dart';
import 'package:smartagri/design_system/tokens.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';
import 'package:smartagri/features/profile/profile_page.dart';

import '../app_test_utils.dart';

List<Quota> quotaFixtures() {
  return const <Quota>[
    Quota(metric: 'plots', limit: 100, used: 69, remaining: 31),
    Quota(metric: 'diagnostics_per_month', limit: 100, used: 70, remaining: 30),
    Quota(metric: 'storage_mb', limit: 100, used: 99, remaining: 1),
    Quota(
      metric: 'llm_messages_per_month',
      limit: 100,
      used: 100,
      remaining: 0,
    ),
    Quota(metric: 'video_analyses_per_month', limit: -1, used: 0, remaining: 0),
  ];
}

Color? quotaColor(WidgetTester tester, String metric) {
  final Finder bar = find.descendant(
    of: find.byKey(Key('profile_quota_$metric')),
    matching: find.byType(AppProgressBar),
  );
  if (bar.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<AppProgressBar>(bar).color;
}

Future<void> pumpProfile(
  WidgetTester tester,
  FakeMeRepository repository, {
  RecordingAuthRepository? authRepository,
  bool stale = false,
}) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: repository,
    authRepository: authRepository ?? RecordingAuthRepository(),
    stale: stale,
  );
  await tester.pumpWidget(testApp(container, const ProfilePage()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the name, the formatted phone and the quotas', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      FakeMeRepository(sampleMeData(quotas: quotaFixtures())),
    );

    expect(find.text('Amina Diallo'), findsOneWidget);
    expect(find.text('+227 90 20 30 40'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Mon utilisation'), findsOneWidget);
    expect(find.text('parcelles'), findsOneWidget);
    expect(find.text('diagnostics ce mois-ci'), findsOneWidget);
    expect(find.text('stockage en Mo'), findsOneWidget);
    expect(find.text("messages de l'assistant"), findsOneWidget);
    expect(find.text('analyses vidéo'), findsOneWidget);
    expect(find.text('69 / 100'), findsOneWidget);
    expect(find.text('70 / 100'), findsOneWidget);
    expect(find.text('99 / 100'), findsOneWidget);
    expect(find.text('100 / 100'), findsOneWidget);
    expect(find.text('Illimité'), findsOneWidget);
  });

  testWidgets('uses the quota colour thresholds', (WidgetTester tester) async {
    await pumpProfile(
      tester,
      FakeMeRepository(sampleMeData(quotas: quotaFixtures())),
    );

    expect(quotaColor(tester, 'plots'), AppColors.tertiary);
    expect(quotaColor(tester, 'diagnostics_per_month'), AppColors.secondary);
    expect(quotaColor(tester, 'storage_mb'), AppColors.secondary);
    expect(quotaColor(tester, 'llm_messages_per_month'), AppColors.danger);
    expect(quotaColor(tester, 'video_analyses_per_month'), isNull);
  });

  testWidgets('logout asks for confirmation and calls the repository', (
    WidgetTester tester,
  ) async {
    final RecordingAuthRepository auth = RecordingAuthRepository();
    await pumpProfile(
      tester,
      FakeMeRepository(sampleMeData()),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('profile_logout')));
    await tester.pumpAndSettle();

    expect(
      find.text('Voulez-vous vraiment vous déconnecter ?'),
      findsOneWidget,
    );
    expect(auth.logoutCalls, 0);

    await tester.tap(find.byKey(const Key('profile_logout_confirm')));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
  });

  testWidgets('cancelling the logout does nothing', (
    WidgetTester tester,
  ) async {
    final RecordingAuthRepository auth = RecordingAuthRepository();
    await pumpProfile(
      tester,
      FakeMeRepository(sampleMeData()),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('profile_logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_logout_cancel')));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 0);
  });

  testWidgets('shows the error state and retries', (WidgetTester tester) async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData())
      ..error = ApiException.network();
    await pumpProfile(tester, repository);

    expect(find.text('Réessayer'), findsOneWidget);

    repository.error = null;
    await tester.tap(find.byKey(const Key('profile_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Amina Diallo'), findsOneWidget);
    expect(find.text('+227 90 20 30 40'), findsOneWidget);
  });

  testWidgets('marks the data as cached after a failed refresh', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, FakeMeRepository(sampleMeData()), stale: true);

    expect(find.text('Amina Diallo'), findsOneWidget);
    expect(find.text('Données en cache'), findsOneWidget);
  });
}
