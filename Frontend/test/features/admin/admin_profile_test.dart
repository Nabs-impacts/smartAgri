import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/profile/profile_page.dart';

import '../app_test_utils.dart';

void main() {
  testWidgets('the administrator profile hides the quotas and diagnostics', (
    WidgetTester tester,
  ) async {
    final container = await buildTestContainer(
      meRepository: FakeMeRepository(
        sampleMeData(fullName: 'Moussa Administrateur', role: 'gov_admin'),
      ),
    );
    await tester.pumpWidget(testApp(container, const ProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('Moussa Administrateur'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Mon utilisation'), findsNothing);
    expect(find.text('Mes diagnostics'), findsNothing);
    expect(find.byKey(const Key('profile_diagnostics')), findsNothing);
    expect(
      find.byKey(const Key('profile_quota_diagnostics_per_month')),
      findsNothing,
    );
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}
