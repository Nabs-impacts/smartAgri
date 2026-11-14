import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_async_view.dart';
import 'package:smartagri/design_system/components/app_pressable.dart';
import 'package:smartagri/design_system/components/app_skeleton.dart';
import 'package:smartagri/design_system/theme.dart';

Widget _app(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (BuildContext context, Widget? page) {
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: page!,
      );
    },
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('AppPressable scales on press and stays still when reduced', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(AppPressable(onTap: () {}, child: const SizedBox(width: 120))),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(
        AppPressable(onTap: () {}, child: const SizedBox(width: 120)),
        disableAnimations: true,
      ),
    );
    final TestGesture reduced = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await reduced.up();
  });

  testWidgets('AppSkeleton animates only when motion is allowed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const AppSkeletonScope(child: AppSkeleton())));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AppSkeletonScope),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        const AppSkeletonScope(child: AppSkeleton()),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AppSkeletonScope),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('AppAsyncView swaps between loading and data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppAsyncView<String>(
          value: const AsyncValue<String>.loading(),
          loadingBuilder: (BuildContext context) => const Text('Chargement'),
          builder: (BuildContext context, String value) => Text(value),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chargement'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        AppAsyncView<String>(
          value: const AsyncValue<String>.data('Prêt'),
          loadingBuilder: (BuildContext context) => const Text('Chargement'),
          builder: (BuildContext context, String value) => Text(value),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Prêt'), findsOneWidget);
    expect(find.text('Chargement'), findsNothing);
  });
}
