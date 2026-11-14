import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/haptics/app_haptics.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/features/profile/profile_page.dart';

import '../app_test_utils.dart';

void main() {
  testWidgets('the vibrations switch persists the preference', (
    WidgetTester tester,
  ) async {
    AppHaptics.enabled.value = true;
    addTearDown(() => AppHaptics.enabled.value = true);
    final container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      initialPreferences: const <String, Object>{'app_haptics': true},
    );
    await tester.pumpWidget(testApp(container, const ProfilePage()));
    await tester.pumpAndSettle();

    final Finder toggle = find.byKey(const Key('profile_haptics'));
    await tester.scrollUntilVisible(toggle, 300);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(container.read(hapticsControllerProvider), isFalse);
    expect(
      container.read(sharedPreferencesProvider).getBool('app_haptics'),
      isFalse,
    );
  });
}
