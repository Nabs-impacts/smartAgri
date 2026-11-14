import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/app_motion.dart';

enum AppPageTransition { horizontal, fade, vertical }

class AppPage<T> extends CustomTransitionPage<T> {
  AppPage({
    required super.child,
    this.transition = AppPageTransition.horizontal,
    super.key,
  }) : super(
         transitionDuration: AppMotion.medium,
         reverseTransitionDuration: AppMotion.medium,
         transitionsBuilder: (
           BuildContext context,
           Animation<double> animation,
           Animation<double> secondaryAnimation,
           Widget child,
         ) => buildAppTransition(context, animation, child, transition),
       );

  final AppPageTransition transition;
}

Widget buildAppTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
  AppPageTransition transition,
) {
  if (AppMotion.animationsDisabled(context)) {
    return child;
  }
  final Animation<double> curved = CurvedAnimation(
    parent: animation,
    curve: AppMotion.enter,
    reverseCurve: AppMotion.exit,
  );
  switch (transition) {
    case AppPageTransition.fade:
      return FadeTransition(opacity: curved, child: child);
    case AppPageTransition.horizontal:
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    case AppPageTransition.vertical:
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
  }
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildAppTransition(
      context,
      animation,
      child,
      AppPageTransition.horizontal,
    );
  }
}

const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
  },
);
